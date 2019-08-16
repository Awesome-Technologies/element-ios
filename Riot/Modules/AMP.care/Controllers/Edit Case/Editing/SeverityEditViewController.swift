//
//  SeverityEditViewController.swift
//  Riot
//
//  Created by Marco Festini on 18.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class SeverityEditViewController: UIViewController, EditingView, UITableViewDelegate, UITableViewDataSource {
    weak var delegate: RowEditingDelegate!
    var currentRow: Row!
    @IBOutlet weak var tableView: UITableView!
    
    var selectedSeverity: Case.Severity!
    var severeties: [Case.Severity] = [.info, .request, .urgent, .critical]
    
    @objc class func fromNib() -> SeverityEditViewController {
        let result = SeverityEditViewController(nibName: String(describing: self), bundle: nil)
        // Force building view hierarchy so all ui bindings are in place
        _ = result.view
        return result
    }
    
    override func viewDidLoad() {
        tableView.tableFooterView = UIView()
    }
    
    func setInitialData(_ data: (value: Any?, date: Date?)) {
        if let value = data.value as? Case.Severity {
            selectedSeverity = value
        }
    }
    
    func saveChanges() {
        delegate.finishedEditing(ofRow: currentRow, result: selectedSeverity)
        
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return severeties.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "Default")
        
        let thisSeverity = severeties[indexPath.row]
        cell.textLabel?.text = thisSeverity.localized()
        
        if thisSeverity == selectedSeverity {
            cell.backgroundColor = thisSeverity.color()
            cell.accessoryType = .checkmark
            cell.textLabel?.textColor = UIColor.white
        } else {
            let coloredBar = UIView(frame: CGRect(x: 0, y: 0, width: 6, height: cell.frame.height))
            coloredBar.backgroundColor = thisSeverity.color()
            cell.addSubview(coloredBar)
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedSeverity = severeties[indexPath.row]
        
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadData()
        
        saveChanges()
    }
}
