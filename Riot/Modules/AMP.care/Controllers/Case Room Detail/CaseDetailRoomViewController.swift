//
//  CaseDetailRoomViewController.swift
//  Riot
//
//  Created by Marco Festini on 24.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class CaseDetailRoomViewController: CaseDetailViewController, CaseListener {
    
    @IBOutlet private weak var editDataButton: UIButton!
    
    private var caseListener: ObserverToken!
    private var messageListener: Any!
    @objc var dataSource: MXKRoomDataSource!
    @objc var room: MXRoom! {
        willSet {
            unregisterListeners()
        }
        didSet {
            if tableView != nil {
                refreshData()
            }
        }
    }
    var attachments = [MXKAttachment]() {
        didSet {
            setupSections()
        }
    }
    
    let reuseIdentifierForCells = "Default"
    
    private let itemsPerRow: CGFloat = 3
    private let collectionInsets = UIEdgeInsets(top: 10.0,
                                                left: 15.0,
                                                bottom: 10.0,
                                                right: 15.0)
    private let padding: CGFloat = 15
    private var picturesCell: PicturesTableViewCell!
    
    @objc class func nib() -> UINib? {
        return UINib(nibName: String(describing: self), bundle: nil)
    }
    
    @objc override class func fromNib() -> CaseDetailRoomViewController {
        let vc = CaseDetailRoomViewController(nibName: String(describing: self), bundle: nil)
        // Force building view hierarchy so all ui bindings are in place
        _ = vc.view
        return vc
    }
    
    @objc override func setupHeader() {
        super.setupHeader()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(showChat))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        ThemeService.shared().theme.applyStyle(onButton: editDataButton)
        editDataButton.setTitle(NSLocalizedString("edit_case_button", tableName: "AMPcare", comment: ""), for: .normal)
        
        refreshData()
        registerListeners()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if room != nil {
            room.markAllAsRead()
        }
    }
    
    override func setupSections() {
        sections.removeAll()
        
        var array = [Row]()
        array.append(.patient)
        array.append(.created)
        array.append(.requester)
        array.append(.severity)
        sections.append(Section(rows: array, title: ""))
        
        array = [Row]()
        array.append(.title)
        if caseData?.caseCore?.note != nil {
            array.append(.note)
        }
        sections.append(Section(rows: array, title: NSLocalizedString("case_detail_section_message", tableName: "AMPcare", comment: "")))
        
        array = [Row]()
        if caseData?.observations.keys.contains(.responsiveness) == true {
            array.append(.responsiveness)
        }
        if caseData?.observations.keys.contains(.pain) == true {
            array.append(.pain)
        }
        if caseData?.observations.keys.contains(.misc) == true {
            array.append(.misc)
        }
        if caseData?.observations.keys.contains(.lastDefecation) == true {
            array.append(.lastDefecation)
        }
        if array.count > 0 {
            sections.append(Section(rows: array, title: NSLocalizedString("case_detail_section_anamnesis", tableName: "AMPcare", comment: "")))
        }
        
        array = [Row]()
        if caseData?.observations.keys.contains(.bodyWeight) == true {
            array.append(.bodyWeight)
        }
        if caseData?.observations.keys.contains(.bodyTemperature) == true {
            array.append(.bodyTemperature)
        }
        if caseData?.observations.keys.contains(.glucose) == true {
            array.append(.glucose)
        }
        if caseData?.observations.keys.contains(.bloodPressure) == true {
            array.append(.bloodPressure)
        }
        if caseData?.observations.keys.contains(.heartRate) == true {
            array.append(.heartRate)
        }
        if caseData?.observations.keys.contains(.oxygen) == true {
            array.append(.oxygen)
        }
        if array.count > 0 {
            sections.append(Section(rows: array, title: NSLocalizedString("case_detail_section_vitals", tableName: "AMPcare", comment: "")))
        }
        
        array = [Row]()
        if attachments.count > 0 {
            array.append(.pictures)
        }
        sections.append(Section(rows: array, title: String(format: NSLocalizedString("number_of_pictures", tableName: "AMPcare", comment: ""), attachments.count)))
        
        tableView.reloadData()
    }
    
    @objc func showChat() {
        let roomViewController = RoomViewController(nibName: String(describing: RoomViewController.self), bundle: nil)
        
        roomViewController.displayRoom(dataSource)
        
        self.show(roomViewController, sender: self)
    }
    
    func updatedCaseCore(_ core: CaseCore?) {
        tableView?.reloadData()
    }
    
    func updatedPatient(_ patient: Patient?) {
        if let indexPath = self.indexPath(forRow: .patient) {
            self.tableView?.reloadRows(at: [indexPath], with: .automatic)
        } else {
            self.tableView?.reloadData()
        }
    }
    
    func updatedObservations(_ observations: [Observation.Identifier: Observation]?) {
        tableView?.reloadData()
    }
    
    func registerListeners() {
        
        caseData = CaseManager.shared.getCase(for: room.roomId)
        guard let caseData = caseData else { return }
        if caseListener == nil {
            caseListener = caseData.addObserver(self)
        }
        if messageListener == nil {
            messageListener = room.listen(toEventsOfTypes: [MXEventType.roomMessage.identifier]) { (event, direction, prevState) in
                if let event = event, event.isMediaAttachment(), let indexPath = self.indexPath(forRow: .pictures) {
                    self.tableView?.reloadSections(IndexSet(integer: indexPath.section), with: .automatic)
                }
            }
        }
    }
    
    @objc func refreshData() {
        tableView?.reloadData()
        
        dataSource.paginate(50, direction: MXTimelineDirection.backwards.identifier, onlyFromStore: false, success: { _ in
            if let attachments = self.dataSource.attachmentsWithThumbnail as? [MXKAttachment] {
                self.attachments = self.attachments.filter {
                    attachments.contains($0)
                }
                self.attachments.append(contentsOf: attachments.filter({
                    !self.attachments.contains($0)
                }))
                
            }
        }, failure: { error in
            print("\(#function) Error paginating attachments")
            if let error = error {
                print(error.localizedDescription)
            }
        })
    }
    
    fileprivate func unregisterListeners() {
        if caseListener != nil {
            caseListener.deregister()
            caseListener = nil
        }
        if room != nil {
            room.removeListener(messageListener)
            messageListener = nil
        }
    }
    
    deinit {
        unregisterListeners()
    }
    
    @IBAction private func editDataClicked(_ sender: Any) {
        let vc = CaseEditViewController.fromNib()
        
        vc.session = session
        
        let newCaseNavigationController = UINavigationController(rootViewController: vc)
        newCaseNavigationController.modalPresentationStyle = .formSheet
        vc.editMode = .edit(room: room)
        vc.setupHeader()
        
        self.present(newCaseNavigationController, animated: true, completion: nil)
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        
        let row = sections[indexPath.section].rows[indexPath.row]
        
        if row == .created && room != nil {
            cell = tableView.dequeueReusableCell(withIdentifier: "Default")
            if cell == nil {
                cell = UITableViewCell(style: .value1, reuseIdentifier: "Default")
            }
            cell.textLabel?.text = NSLocalizedString(row.rawValue, tableName: "AMPcare", comment: "")
            room.state({ state in
                if let event = state?.stateEvents(with: MXEventType.roomCreate)?.last, event.originServerTs != kMXUndefinedTimestamp {
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .short
                    dateFormatter.timeStyle = .short
                    dateFormatter.doesRelativeDateFormatting = true
                    let dateString = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(event.originServerTs / 1000)))
                    
                    cell.detailTextLabel?.text = dateString
                }
            })
        } else {
            if row == .pictures {
                cell = tableView.dequeueReusableCell(withIdentifier: PicturesTableViewCell.defaultReuseIdentifier())
                if let myCell = cell as? PicturesTableViewCell {
                    picturesCell = myCell
                    myCell.collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifierForCells)
                    myCell.collectionView.register(MXKMediaCollectionViewCell.nib(), forCellWithReuseIdentifier: MXKMediaCollectionViewCell.defaultReuseIdentifier())
                    myCell.collectionView.delegate = self
                    myCell.collectionView.dataSource = self
                    myCell.collectionView.reloadData()
                }
            } else {
                cell = super.tableView(tableView, cellForRowAt: indexPath)
            }
        }
        return cell
    }
}

extension CaseDetailRoomViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = sections[indexPath.section].rows[indexPath.row]
        
        if row == .pictures {
            picturesCell.setNeedsLayout()
            picturesCell.layoutIfNeeded()
            return picturesCell.collectionView.intrinsicContentSize.height
        } else {
            return UITableView.automaticDimension
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let paddingSpace = padding * (itemsPerRow - 1) + collectionInsets.left + collectionInsets.right
        let availableWidth = tableView.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return collectionInsets
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return collectionInsets.left
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let attachmentsViewController = MXKAttachmentsViewController()
        attachmentsViewController.complete = true
        attachmentsViewController.displayAttachments(attachments, focusOn: attachments[indexPath.row].eventId)
        self.present(attachmentsViewController, animated: true, completion: nil)
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return attachments.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MXKMediaCollectionViewCell.defaultReuseIdentifier(), for: indexPath) as? MXKMediaCollectionViewCell
            else { return collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierForCells, for: indexPath) }
        
        cell.mxkImageView.setAttachment(attachments[indexPath.row])
        cell.mxkImageView.stretchable = true
        cell.mxkImageView.defaultBackgroundColor = .clear
        cell.mxkImageView.isUserInteractionEnabled = false
        
        return cell
    }
}
