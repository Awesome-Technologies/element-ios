//
//  CaseDetailViewController.swift
//  Riot
//
//  Created by Marco Festini on 24.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class CaseDetailViewController: MXKViewController, UITableViewDataSource, UITableViewDelegate {
    
    var caseData: Case? {
        didSet {
            tableView?.reloadData()
        }
    }
    @objc var session: MXSession!
    var sections = [Section]()

    @IBOutlet weak var tableView: UITableView!
    
    @objc class func fromNib() -> CaseDetailViewController {
        let vc = CaseDetailViewController(nibName: String(describing: self), bundle: nil)
        // Force building view hierarchy so all ui bindings are in place
        _ = vc.view
        return vc
    }
    
    @objc func setupHeader() {
        navigationItem.title = NSLocalizedString("case_detail_title", tableName: "AMPcare", comment: "")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        setupSections()
        
        if let navBar = self.navigationController?.navigationBar {
            ThemeService.shared().theme.applyStyle(onNavigationBar: navBar)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(TwoLabelTableViewCell.nib(), forCellReuseIdentifier: TwoLabelTableViewCell.defaultReuseIdentifier())
        tableView.register(MultiLineTableViewCell.nib(), forCellReuseIdentifier: MultiLineTableViewCell.defaultReuseIdentifier())
        tableView.register(PicturesTableViewCell.nib(), forCellReuseIdentifier: PicturesTableViewCell.defaultReuseIdentifier())
        
        tableView.tableFooterView = UIView()
    }
    
    func indexPath(forRow row: Row) -> IndexPath? {
        var sectionIndex = 0
        var rowIndex = 0
        for section in sections {
            for temp in section.rows {
                if temp == row {
                    return IndexPath(row: rowIndex, section: sectionIndex)
                }
                rowIndex += 1
            }
            sectionIndex += 1
        }
        
        return nil
    }
    
    func setupSections() {
        print("Not implemented!")
    }
    
    // MARK: - UITableViewDelegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        
        let row = sections[indexPath.section].rows[indexPath.row]
        
        if row != .patient && row != .note {
            cell = tableView.dequeueReusableCell(withIdentifier: "Default")
            if cell == nil {
                cell = UITableViewCell(style: .value1, reuseIdentifier: "Default")
            }
            cell.textLabel?.text = NSLocalizedString(row.rawValue, tableName: "AMPcare", comment: "")
            
            if row.isObservation(), let identifier = row.observationIdentifier(), let observation = caseData?.observations[identifier] {
                let str: String? = observation.humanReadableValue
                let date: Date? = observation.effectiveDateTime
                if row == .pain || row == .misc {
                    cell = tableView.dequeueReusableCell(withIdentifier: MultiLineTableViewCell.defaultReuseIdentifier())
                    if let myCell = cell as? MultiLineTableViewCell {
                        myCell.leftLabel.text = identifier.localized()
                        myCell.textView.text = str
                        if date != nil {
                            myCell.rightLabel.text = caseData?.observations[identifier]?.humanReadableEffectiveDateTime
                        } else {
                            myCell.rightLabel.text = ""
                        }
                    }
                } else if date != nil && row != .lastDefecation {
                    cell = tableView.dequeueReusableCell(withIdentifier: TwoLabelTableViewCell.defaultReuseIdentifier())
                    if let myCell = cell as? TwoLabelTableViewCell {
                        myCell.leftLabel.text = identifier.localized()
                        myCell.rightTopLabel.text = str
                        myCell.rightBottomLabel.text = caseData?.observations[identifier]?.humanReadableEffectiveDateTime
                    }
                } else {
                    cell.detailTextLabel?.text = str
                }
            }
            cell.backgroundColor = nil
        }
        
        switch row {
        case .patient:
            cell = tableView.dequeueReusableCell(withIdentifier: TwoLabelTableViewCell.defaultReuseIdentifier())
            if let myCell = cell as? TwoLabelTableViewCell {
                myCell.leftLabel.text = NSLocalizedString(row.rawValue, tableName: "AMPcare", comment: "")
                myCell.rightTopLabel.text = caseData?.patient?.name
                
                var finalString = ""
                if let age = caseData?.patient?.age, let gender = caseData?.patient?.gender {
                    let genderString = gender.localized()
                    
                    if age > 0 {
                        finalString = "\(genderString) \(String(age)) \(NSLocalizedString("years", tableName: "AMPcare", comment: ""))"
                    } else {
                        finalString = genderString
                    }
                }
                myCell.rightBottomLabel.text = finalString
            }
        case .note:
            cell = tableView.dequeueReusableCell(withIdentifier: MultiLineTableViewCell.defaultReuseIdentifier())
            if let myCell = cell as? MultiLineTableViewCell {
                myCell.leftLabel.text = NSLocalizedString(row.rawValue, tableName: "AMPcare", comment: "")
                myCell.textView.text = caseData?.caseCore?.note
                
                // Colorize background of textfield
                myCell.textView.backgroundColor = caseData?.caseCore?.severity.color()
                myCell.textView.textColor = .white
                myCell.textView.layer.cornerRadius = 10.0
            }
            
        case .severity:
            cell.textLabel?.textColor = .white
            cell.detailTextLabel?.textColor = .white
            cell.detailTextLabel?.text = caseData?.caseCore?.severity.localized()
            cell.backgroundColor = caseData?.caseCore?.severity.color()
            
        case .requester:
            cell.detailTextLabel?.text = caseData?.caseCore?.requester
            
        case .title:
            cell.detailTextLabel?.text = caseData?.caseCore?.title
            
        case .anamnesis:
            var dictCount = 0
            if let dict = caseData?.observations.filter({ $0.key == Observation.Identifier.responsiveness ||
                $0.key == Observation.Identifier.pain ||
                $0.key == Observation.Identifier.misc ||
                $0.key == Observation.Identifier.lastDefecation
            }) {
                dictCount = dict.count
            }
            cell.detailTextLabel?.text = String(format: NSLocalizedString("number_of_entries", tableName: "AMPcare", comment: ""), dictCount)
            
        case .vitals:
            var dictCount = 0
            if let dict = caseData?.observations.filter({ $0.key == Observation.Identifier.bloodPressure ||
                $0.key == Observation.Identifier.oxygen ||
                $0.key == Observation.Identifier.heartRate ||
                $0.key == Observation.Identifier.glucose ||
                $0.key == Observation.Identifier.bodyWeight ||
                $0.key == Observation.Identifier.bodyTemperature
            }) {
                dictCount = dict.count
            }
            cell.detailTextLabel?.text = String(format: NSLocalizedString("number_of_entries", tableName: "AMPcare", comment: ""), dictCount)
            
        default: break
        }
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "Default")
            cell.textLabel?.text = NSLocalizedString(row.rawValue, tableName: "AMPcare", comment: "")
        }
        return cell
    }
}
