//
//  DateEditViewController.swift
//  Riot
//
//  Created by Marco Festini on 24.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class DateEditViewController: UIViewController, EditingView {
    weak var delegate: RowEditingDelegate!
    var currentRow: Row!

    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var removeDateButton: UIButton!
    
    @objc class func fromNib() -> DateEditViewController {
        let result = DateEditViewController(nibName: String(describing: self), bundle: nil)
        // Force building view hierarchy so all ui bindings are in place
        _ = result.view
        return result
    }
    
    override func viewDidLoad() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveChanges))
        datePicker.datePickerMode = .dateAndTime
        removeDateButton.setTitle(NSLocalizedString("edit_case_remove_date", tableName: "AMPcare", comment: ""), for: .normal)
    }
    
    func setInitialData(_ data: (value: Any?, date: Date?)) {
        if let date = data.value as? Date {
            datePicker.date = date
        } else {
            datePicker.date = Date()
        }
        datePicker.maximumDate = Date()
    }
    
    @objc func saveChanges() {
        delegate.finishedEditing(ofRow: currentRow, result: datePicker.date)
        
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction private func removeDate(_ sender: Any) {
        delegate.finishedEditing(ofRow: currentRow, result: nil)
        
        navigationController?.popViewController(animated: true)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
