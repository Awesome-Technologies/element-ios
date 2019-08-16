//
//  AnamnesisViewController.swift
//  Riot
//
//  Created by Marco Festini on 24.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class AnamnesisViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, EditingView, RowEditingDelegate {
    weak var delegate: RowEditingDelegate!
    var currentRow: Row!
    
    @IBOutlet weak var tableView: UITableView!
    
    var sections: Section!
    var observations = [Row: Observation]()
    
    @objc class func fromNib() -> AnamnesisViewController {
        let vc = AnamnesisViewController(nibName: String(describing: self), bundle: nil)
        // Force building view hierarchy so all ui bindings are in place
        _ = vc.view
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView()
        
        tableView.register(MultiLineTableViewCell.nib(), forCellReuseIdentifier: MultiLineTableViewCell.defaultReuseIdentifier())
        tableView.register(TwoLabelTableViewCell.nib(), forCellReuseIdentifier: TwoLabelTableViewCell.defaultReuseIdentifier())

        sections = Section(rows: [.responsiveness, .pain, .misc, .lastDefecation], title: "")
    }
    
    func addObservation(_ observation: Observation?) {
        guard let observation = observation, let row = Row(rawValue: observation.id.rawValue) else { return }
        
        observations[row] = observation
    }
    
    // MARK: - RowEditingDelegate
    
    func finishedEditing(ofRow row: Row, result: Any?) {
        switch row {
        case .responsiveness:
            if let result = result as? (text: String, date: Date?), !result.text.isEmpty {
                observations[.responsiveness] = Observation.responsivenessObservation(desc: result.text, date: result.date)
            } else {
                observations.removeValue(forKey: .responsiveness)
            }
            
        case .pain:
            if let result = result as? (text: String, date: Date?), !result.text.isEmpty {
                observations[.pain] = Observation.painObservation(desc: result.text, date: result.date)
            } else {
                observations.removeValue(forKey: .pain)
            }
            
        case .misc:
            if let result = result as? (text: String, date: Date?), !result.text.isEmpty {
                observations[.misc] = Observation.miscObservation(desc: result.text, date: result.date)
            } else {
                observations.removeValue(forKey: .misc)
            }
            
        case .lastDefecation:
            if let result = result as? Date {
                observations[.lastDefecation] = Observation.lastDefecationObservation(date: result)
            } else {
                observations.removeValue(forKey: .lastDefecation)
            }
            
        default: break
        }
        
        delegate.finishedEditing(ofRow: row, result: observations[row])
        
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections == nil ? 0 : sections.rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        
        let row = sections.rows[indexPath.row]
        let type = row.observationIdentifier()
        
        if type == .misc || type == .pain {
            cell = tableView.dequeueReusableCell(withIdentifier: MultiLineTableViewCell.defaultReuseIdentifier())
            if let myCell = cell as? MultiLineTableViewCell {
                myCell.textView.text = observations[row]?.humanReadableValue
                myCell.leftLabel.text = type?.localized()
                if observations[row]?.effectiveDateTime != nil {
                    myCell.rightLabel.text = observations[row]?.humanReadableEffectiveDateTime
                }
                cell = myCell
            }
        } else if observations[row]?.effectiveDateTime != nil && type != .lastDefecation {
            cell = tableView.dequeueReusableCell(withIdentifier: TwoLabelTableViewCell.defaultReuseIdentifier())
            if let myCell = cell as? TwoLabelTableViewCell {
                myCell.leftLabel.text = type?.localized()
                myCell.rightTopLabel.text = observations[row]?.humanReadableValue
                myCell.rightBottomLabel.text = observations[row]?.humanReadableEffectiveDateTime
            }
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "Default")
            if cell == nil {
                cell = UITableViewCell(style: .value1, reuseIdentifier: "Default")
            }
            
            cell?.textLabel?.text = type?.localized()
            cell.detailTextLabel?.text = observations[row]?.humanReadableValue
        }
        if cell == nil {
            cell = UITableViewCell(style: .value1, reuseIdentifier: "Default")
        }
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var vc: UIViewController?
        
        let row = sections.rows[indexPath.row]
        
        switch row {
        case .responsiveness:
            let viewController = SingleLineEditViewController.fromNib()
            viewController.setPlaceholder(NSLocalizedString("edit_case_responsiveness_placeholder", tableName: "AMPcare", comment: ""))
            viewController.setInitialData((observations[.responsiveness]?.value, observations[.responsiveness]?.effectiveDateTime), showDate: true)
            viewController.currentRow = row
            viewController.delegate = self
            vc = viewController
            
        case .pain:
            let viewController = MultiLineEditViewController.fromNib()
            viewController.setPlaceholder(NSLocalizedString("edit_case_pain_placeholder", tableName: "AMPcare", comment: ""))
            viewController.setInitialData((observations[.pain]?.value, observations[.pain]?.effectiveDateTime), showDate: true)
            viewController.currentRow = row
            viewController.delegate = self
            vc = viewController
            
        case .misc:
            let viewController = MultiLineEditViewController.fromNib()
            viewController.setPlaceholder(NSLocalizedString("edit_case_misc_placeholder", tableName: "AMPcare", comment: ""))
            viewController.setInitialData((observations[.misc]?.value, observations[.misc]?.effectiveDateTime), showDate: true)
            viewController.currentRow = row
            viewController.delegate = self
            vc = viewController
            
        case .lastDefecation:
            let viewController = DateEditViewController.fromNib()
            viewController.setInitialData((observations[.lastDefecation]?.effectiveDateTime, nil))
            viewController.currentRow = row
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
}
