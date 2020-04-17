//
//  CaseEditViewController.swift
//  Riot
//
//  Created by Marco Festini on 11.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class CaseEditViewController: CaseDetailViewController, RowEditingDelegate, PicturesEditDelegate, ContactsTableViewControllerDelegate {
    public enum EditMode {
        case new
        case edit(room: MXRoom)
    }
    
    var editMode = EditMode.new {
        didSet {
            switch editMode {
            case .edit(let room):
                if let caseData = CaseManager.shared.getCase(for: room.roomId)?.copy() as? Case {
                    self.caseData = caseData
                }
            default:
                break
            }
        }
    }
    
    var selectedContact: MXKContact? {
        didSet {
            updateRightBarButton()
            if let indexPath = indexPath(forRow: .recipient) {
                tableView.reloadRows(at: [indexPath], with: .none)
            } else {
                tableView.reloadData()
            }
        }
    }
    var pictures = [UIImage]() {
        didSet {
            setupSections()
            updateRightBarButton()
            tableView.reloadData()
        }
    }
    
    @IBOutlet weak var activityView: UIView!
    
    // Prevent events from being sent twice.
    private var finished = false
    
    @objc override class func fromNib() -> CaseEditViewController {
        let vc = CaseEditViewController(nibName: String(describing: self), bundle: nil)
        // Force building view hierarchy so all ui bindings are in place
        _ = vc.view
        return vc
    }
    
    @objc func close() {
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if caseData == nil {
            caseData = Case(withCore: CaseCore(title: "", severity: .info, requester: session.myUser.displayname))
        }
        
        activityView.isHidden = true
    }
    
    @objc override func setupHeader() {
        switch editMode {
        case .new:
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(createNewCase))
            navigationItem.title = NSLocalizedString("new_case_title", tableName: "AMPcare", comment: "")
            
        case .edit:
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(commitChanges))
            navigationItem.title = NSLocalizedString("edit_case_title", tableName: "AMPcare", comment: "")
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem?.isEnabled = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.reloadData()
    }
    
    override func setupSections() {
        sections.removeAll()
        
        switch editMode {
        case .new:
            var array = [Row]()
            array.append(.patient)
            array.append(.recipient)
            array.append(.requester)
            array.append(.severity)
            sections.append(Section(rows: array, title: ""))
            
            array = [Row]()
            array.append(.title)
            array.append(.note)
            sections.append(Section(rows: array, title: NSLocalizedString("case_detail_section_message", tableName: "AMPcare", comment: "")))
            
            array = [Row]()
            array.append(.anamnesis)
            array.append(.vitals)
            array.append(.pictures)
            sections.append(Section(rows: array, title: NSLocalizedString("case_detail_section_data", tableName: "AMPcare", comment: "")))
            
        case .edit:
            var array = [Row]()
            array.append(.patient)
            sections.append(Section(rows: array, title: ""))
            
            array = [Row]()
            array.append(.anamnesis)
            array.append(.vitals)
            array.append(.pictures)
            sections.append(Section(rows: array, title: NSLocalizedString("case_detail_section_data", tableName: "AMPcare", comment: "")))
        }
        
        tableView.reloadData()
    }
    
    func updateRightBarButton() {
        switch editMode {
        case .new:
            let caseCore = caseData?.caseCore
            guard let title = caseCore?.title, caseCore?.severity != nil, let requester = caseCore?.requester else {
                navigationItem.rightBarButtonItem?.isEnabled = false
                return
            }
            navigationItem.rightBarButtonItem?.isEnabled = selectedContact != nil && !title.isEmpty && !requester.isEmpty
            
        case .edit:
            if let caseData = caseData {
                navigationItem.rightBarButtonItem?.isEnabled = caseData.observations.count > 0 || self.pictures.count > 0
            }
        }
    }
    
    // MARK: - Creating/Editing a case
    
    private func findDifferingObservations() -> [Observation]? {
        switch editMode {
        case .edit(let room):
            guard let caseData = caseData, let originalObservations = CaseManager.shared.getCase(for: room.roomId)?.observations else { return nil }
            var newObservations = [Observation]()
            
            for observation in caseData.observations.values {
                if originalObservations.keys.contains(observation.id), let origObservation = originalObservations[observation.id] {
                    // Type already exists -> Check everything
                    if observation == origObservation {
                        continue
                    }
                }
                newObservations.append(observation)
            }
            
            return newObservations
        default: break
        }
        
        return nil
    }
    
    @objc func commitChanges() {
        activityView.isHidden = false
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        switch editMode {
        case .edit(let room):
            
            func sendPatientDataAndPictures() {
                // Check if patient data has changed
                if let oldCaseData = CaseManager.shared.getCase(for: room.roomId), let caseData = self.caseData, oldCaseData.patient != caseData.patient {
                    self.sendPatientEvent(toRoom: room) {
                        self.sendPictures(self.pictures, toRoom: room, completion: {
                            self.close()
                        })
                    }
                } else {
                    self.sendPictures(self.pictures, toRoom: room, completion: {
                        self.close()
                    })
                }
            }
            
            // Find observations that have actually changed
            if let observations = findDifferingObservations() {
                self.sendObservations(Array(observations), toRoom: room, completion: {
                    sendPatientDataAndPictures()
                })
            } else {
                sendPatientDataAndPictures()
            }
        default: break
        }
    }
    
    @objc func createNewCase() {
        guard session != nil, let userId = self.selectedContact?.matrixIdentifiers.first as? String else {
            close()
            return
        }
        activityView.isHidden = false
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        print("\(#function) Creating new case.")
        
        let parameters: [String: Any] = ["preset": MXRoomPreset.trustedPrivateChat.identifier,
                                         "is_direct": true,
                                         "invite": [userId]]
        
        session.createRoom(parameters: parameters) { responseCreateRoom in
            
            if responseCreateRoom.isSuccess, let room = responseCreateRoom.value {
                room.enableEncryption(withAlgorithm: kMXCryptoMegolmAlgorithm, completion: { response in
                    if !self.finished {
                        self.finished = true
                        print("\(#function) Success!")
                        self.sendCaseEvent(toRoom: room, completion: {})
                        self.sendPatientEvent(toRoom: room, completion: {})
                        if let observations = self.caseData?.observations.values {
                            self.sendObservations(Array(observations), toRoom: room, completion: {})
                        }
                        self.sendPictures(self.pictures, toRoom: room, completion: {})
                        
                        self.close()
                    }
                })
            }
        }
    }
    
    private func sendCaseEvent(toRoom room: MXRoom, completion: @escaping () -> Void) {
        print("Sending case data")
        if let caseCore = self.caseData?.caseCore {
            room.sendStateEvent(Case.EventType.case.mxEventType(), content: caseCore.jsonRepresentation(), stateKey: Case.EventType.case.rawValue, completion: { response in
                if response.isSuccess {
                    print("Seemed to have worked!")
                    completion()
                } else if response.isFailure, let error = response.error as NSError? {
                    print("Error: \(String(describing: error))")
                    if let devices = error.userInfo[MXEncryptingErrorUnknownDeviceDevicesKey] as? MXUsersDevicesMap<MXDeviceInfo> {
                        self.session.crypto.setDevicesKnown(devices, complete: {
                            self.sendCaseEvent(toRoom: room, completion: {
                                completion()
                            })
                        })
                    } else {
                        completion()
                    }
                } else {
                    completion()
                }
            })
        } else {
            completion()
        }
    }
    
    private func sendPatientEvent(toRoom room: MXRoom, completion: @escaping () -> Void) {
        print("Sending patient data")
        if let patient = self.caseData?.patient {
            room.sendStateEvent(Case.EventType.patient.mxEventType(), content: patient.jsonRepresentation(), stateKey: Case.EventType.patient.rawValue, completion: { response in
                if response.isSuccess {
                    print("Seemed to have worked!")
                    completion()
                } else if response.isFailure, let error = response.error as NSError? {
                    print("Error: \(String(describing: error))")
                    if let devices = error.userInfo[MXEncryptingErrorUnknownDeviceDevicesKey] as? MXUsersDevicesMap<MXDeviceInfo> {
                        self.session.crypto.setDevicesKnown(devices, complete: {
                            self.sendPatientEvent(toRoom: room, completion: {
                                completion()
                            })
                        })
                    } else {
                        completion()
                    }
                } else {
                    completion()
                }
                
            })
        } else {
            completion()
        }
    }
    
    private func sendObservations(_ observations: [Observation], toRoom room: MXRoom, completion: @escaping () -> Void) {
        guard observations.isEmpty == false else {
            completion()
            return
        }
        print("Sending observation data")
        var failedToSend = [Observation]()
        
        var attempts = 0
        let manager = MXKRoomDataSourceManager.sharedManager(forMatrixSession: session)
        
        let checkAttempts = {
            attempts += 1
            if attempts == observations.count {
                self.sendObservations(failedToSend, toRoom: room, completion: {
                    completion()
                })
            }
        }
        
        manager?.roomDataSource(forRoom: room.roomId, create: true, onComplete: { dataSource in
            for observation in observations {
                dataSource?.sendEvent(ofType: Case.EventType.observation.rawValue, content: observation.jsonRepresentation(), success: { _ in
                    checkAttempts()
                }, failure: { error in
                    failedToSend.append(observation)
                    if let error = error as NSError? {
                        print("Error: \(String(describing: error))")
                        if let devices = error.userInfo[MXEncryptingErrorUnknownDeviceDevicesKey] as? MXUsersDevicesMap<MXDeviceInfo> {
                            self.session.crypto.setDevicesKnown(devices, complete: {
                                checkAttempts()
                            })
                        } else {
                            checkAttempts()
                        }
                    } else {
                        checkAttempts()
                    }
                })
            }
        })
    }
    
    private func sendPictures(_ picturArray: [UIImage], toRoom room: MXRoom, completion: @escaping () -> Void) {
        guard picturArray.count > 0 else {
            completion()
            return
        }
        print("Sending pictures")
        var failedToSend = [UIImage]()
        let manager = MXKRoomDataSourceManager.sharedManager(forMatrixSession: session)
        manager?.roomDataSource(forRoom: room.roomId, create: true, onComplete: { dataSource in
            var attempts = 0
            for picture in picturArray {
                dataSource?.send(picture, success: { _ in
                    attempts += 1
                    
                    if attempts == picturArray.count {
                        self.sendPictures(failedToSend, toRoom: room, completion: {
                            completion()
                        })
                    }
                    
                    print("\(#function) Sent image to room")
                }, failure: { error in
                    failedToSend.append(picture)
                    attempts += 1
                    
                    if attempts == picturArray.count {
                        self.sendPictures(failedToSend, toRoom: room, completion: {
                            completion()
                        })
                    }
                    
                    print("\(#function) Error sending image to room")
                    if let error = error {
                        print(error.localizedDescription)
                    }
                })
            }
        })
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        let row = sections[indexPath.section].rows[indexPath.row]
        if row == .recipient {
            cell.detailTextLabel?.text = selectedContact?.displayName
        } else if row == .pictures {
            switch editMode {
            case .edit:
                cell.textLabel?.text = NSLocalizedString("edit_case_add_pictures", tableName: "AMPcare", comment: "")
            default: break
            }
            cell.detailTextLabel?.text = String(format: NSLocalizedString("number_of_pictures", tableName: "AMPcare", comment: ""), pictures.count)
        }
        switch editMode {
        case .new:
            if row != .requester {
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.selectionStyle = .none
            }
        case .edit:
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let row = sections[indexPath.section].rows[indexPath.row]
        
        switch editMode {
        case .new:
            if row == .requester {
                return nil
            }
            
        case .edit: break
        }
        
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = sections[indexPath.section].rows[indexPath.row]
        var vc: UIViewController?
        
        switch row {
        case .note:
            let viewController = MultiLineEditViewController.fromNib()
            viewController.setPlaceholder(NSLocalizedString("edit_case_note_placeholder", tableName: "AMPcare", comment: ""))
            viewController.setInitialData((caseData?.caseCore?.note, nil), showDate: false)
            viewController.currentRow = row
            viewController.delegate = self
            vc = viewController
            
        case .title:
            let viewController = SingleLineEditViewController.fromNib()
            viewController.setPlaceholder(NSLocalizedString("edit_case_title_placeholder", tableName: "AMPcare", comment: ""))
            viewController.setInitialData((caseData?.caseCore?.title, nil), showDate: false)
            viewController.currentRow = row
            viewController.delegate = self
            vc = viewController
            
        case .severity:
            let viewController = SeverityEditViewController.fromNib()
            viewController.setInitialData((caseData?.caseCore?.severity, nil))
            viewController.currentRow = row
            viewController.delegate = self
            vc = viewController
            
        case .patient:
            let viewController = PatientEditViewController.fromNib()
            viewController.setPlaceholder(NSLocalizedString("edit_case_patient_placeholder", tableName: "AMPcare", comment: ""))
            viewController.setInitialData((caseData?.patient, nil))
            viewController.currentRow = row
            viewController.delegate = self
            vc = viewController
            
        case .pictures:
            let viewController = PicturesEditCollectionViewController.fromNib()
            viewController.currentRow = row
            viewController.delegate = self
            viewController.picturesDelegate = self
            vc = viewController
            
        case .recipient:
            let viewController = ContactsTableViewController()
            viewController.contactsTableViewControllerDelegate = self
            viewController.showSearch(false)
            
            let dataSource = ContactsDataSource(matrixSession: session)
            dataSource?.forceRefresh()
            viewController.displayList(dataSource)
            
            vc = viewController
            
        case .anamnesis:
            let viewController = AnamnesisViewController.fromNib()
            viewController.currentRow = row
            viewController.addObservation(caseData?.observations[.responsiveness])
            viewController.addObservation(caseData?.observations[.pain])
            viewController.addObservation(caseData?.observations[.misc])
            viewController.addObservation(caseData?.observations[.lastDefecation])
            viewController.delegate = self
            vc = viewController
            
        case .vitals:
            let viewController = VitalsViewController.fromNib()
            viewController.currentRow = row
            viewController.addObservation(caseData?.observations[.bodyWeight])
            viewController.addObservation(caseData?.observations[.bodyTemperature])
            viewController.addObservation(caseData?.observations[.glucose])
            viewController.addObservation(caseData?.observations[.bloodPressure])
            viewController.addObservation(caseData?.observations[.heartRate])
            viewController.addObservation(caseData?.observations[.oxygen])
            viewController.delegate = self
            vc = viewController
            
        default: break
        }
        
        if let vc = vc {
            vc.title = NSLocalizedString("edit_case_\(row.rawValue)_title", tableName: "AMPcare", comment: "")
            self.show(vc, sender: self)
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - EditingDelegate
    
    func finishedEditing(ofRow row: Row, result: Any?) {
        switch row {
        case .note:
            if let result = result as? (text: String, date: Date?) {
                caseData?.caseCore?.note = result.text
            }
            
        case .title:
            if let result = result as? (text: String, date: Date?) {
                caseData?.caseCore?.title = result.text
            }
            
        case .severity:
            if let result = result as? Case.Severity {
                caseData?.caseCore?.severity = result
            }
            
        case .patient:
            if let result = result as? Patient {
                caseData?.patient = result
            }
            
        case .oxygen, .responsiveness, .pain, .misc, .lastDefecation, .bodyWeight, .bodyTemperature, .glucose, .bloodPressure, .heartRate:
            if let observation = result as? Observation {
                caseData?.setObservation(observation: observation)
            } else if let identifier = row.observationIdentifier() {
                caseData?.removeObservation(withIdentifier: identifier)
            }
            
        default: break
        }
        
        tableView.reloadData()
        updateRightBarButton()
    }
    
    // MARK: - PicturesEditDelegate
    
    func getPictures() -> [UIImage] {
        return pictures
    }
    
    func addedPicture(_ image: UIImage) {
        pictures.append(image)
    }
    
    func removedPicture(at position: Int) {
        pictures.remove(at: position)
    }
    
    // MARK: - ContactsTableViewControllerDelegate
    
    func contactsTableViewController(_ contactsTableViewController: ContactsTableViewController!, didSelect contact: MXKContact!) {
        navigationController?.popToViewController(self, animated: true)
        selectedContact = contact
    }
}
