//
//  CaseTableViewCell.swift
//  Riot
//
//  Created by Marco Festini on 10.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class CaseTableViewCell: MXKRecentTableViewCell, CaseListener {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var patientNameLabel: UILabel!
    @IBOutlet weak var creationDateLabel: UILabel!
    @IBOutlet weak var severityView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var caseCellData: MXKRecentCellDataStoring!
    private var listener: ObserverToken!
    private var room: MXRoom!
    
    override class func nib() -> UINib {
        return UINib(nibName: String(describing: self), bundle: nil)
    }
    
    func updateCaseUserInterface() {
        let caseCore = CaseManager.shared.getCase(for: room.roomId)?.caseCore
        self.nameLabel.text = caseCore?.title
        self.severityView.backgroundColor = caseCore?.severity.color()
    }
    
    func updatePatientUserInterface() {
        let patient = CaseManager.shared.getCase(for: room.roomId)?.patient
        self.patientNameLabel.text = patient?.name
    }
    
    fileprivate func unregisterListeners() {
        guard listener != nil else { return }
        
        listener.deregister()
        listener = nil
    }
    
    deinit {
        unregisterListeners()
    }
    
    // MARK: - MXKCellRendering
    
    fileprivate func pullDataForUI(_ room: MXRoom) {
        if let `case` = CaseManager.shared.getCase(for: room.roomId) {
            listener = `case`.addObserver(self)
            self.updateCaseUserInterface()
            self.updatePatientUserInterface()
        } else {
            let `case` = Case()
            listener = `case`.addObserver(self)
            CaseManager.shared.setCase(`case`, forRoom: room)
        }
        
        // First call, so we have to pull all the data manually
        room.state { stateOpt in
            if let state = stateOpt {
                if let event = state.stateEvents(with: MXEventType.roomCreate)?.last, event.originServerTs != kMXUndefinedTimestamp {
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .short
                    dateFormatter.timeStyle = .short
                    dateFormatter.doesRelativeDateFormatting = true
                    let dateString = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(event.originServerTs / 1000)))
                    
                    self.creationDateLabel.text = dateString
                    self.creationDateLabel.isHidden = false
                } else {
                    self.creationDateLabel.isHidden = true
                }
            }
        }
        
        activityIndicator.stopAnimating()
    }
    
    override func render(_ cellData: MXKCellData!) {
        caseCellData = cellData as? MXKRecentCellDataStoring
        
        if let room = caseCellData.roomSummary.room {
            activityIndicator.startAnimating()
            
            unregisterListeners()
            self.room = room
            
            if room.summary.membership == .invite {
                room.join { response in
                    if response.isSuccess {
                        self.pullDataForUI(room)
                    }
                }
            } else {
                pullDataForUI(room)
            }
        }
    }
    
    func updatedCaseCore() {
        self.updateCaseUserInterface()
    }
    
    func updatedPatient() {
        self.updatePatientUserInterface()
    }
    
    override static func height(for cellData: MXKCellData!, withMaximumWidth maxWidth: CGFloat) -> CGFloat {
        return 74
    }
    
    override func renderedCellData() -> MXKCellData! {
        if let cellData = caseCellData as? MXKCellData {
            return cellData
        } else {
            return nil
        }
    }
}
