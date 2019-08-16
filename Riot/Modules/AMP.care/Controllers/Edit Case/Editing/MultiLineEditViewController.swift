//
//  MultiLineEditViewController.swift
//  Riot
//
//  Created by Marco Festini on 18.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class MultiLineEditViewController: UIViewController, EditingView, UITextViewDelegate {
    weak var delegate: RowEditingDelegate!
    var currentRow: Row!
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var placeholderLabel: UILabel!
    
    @IBOutlet weak var measurementTimeLabel: UILabel!
    @IBOutlet weak var measurementTime: UIDatePicker!
    @IBOutlet weak var showDatePickerSwitch: UISwitch!
    
    @objc class func fromNib() -> MultiLineEditViewController {
        let result = MultiLineEditViewController(nibName: String(describing: self), bundle: nil)
        // Force building view hierarchy so all ui bindings are in place
        _ = result.view
        return result
    }
    
    override func viewDidLoad() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveChanges))
        
        measurementTimeLabel.text = NSLocalizedString("edit_case_measurement_date_label", tableName: "AMPcare", comment: "")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        textView.becomeFirstResponder()
    }
    
    func setInitialData(_ data: (value: Any?, date: Date?), showDate: Bool) {
        measurementTime.maximumDate = Date()
        if let date = data.date {
            measurementTime.date = date
            showDatePickerSwitch.isOn = true
        } else if let maxDate = measurementTime.maximumDate {
            measurementTime.date = maxDate
            showDatePickerSwitch.isOn = false
        } else {
            measurementTime.date = Date()
            showDatePickerSwitch.isOn = false
        }
        
        if let string = data.value as? String {
            textView.text = string
        } else {
            textView.text = ""
        }
        
        measurementTime.isHidden = !showDate || !showDatePickerSwitch.isOn
        measurementTimeLabel.isHidden = !showDate
        showDatePickerSwitch.isHidden = !showDate
        
        updatePlaceholderVisibility()
    }
    
    func setPlaceholder(_ string: String?) {
        placeholderLabel.text = string
        updatePlaceholderVisibility()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholderVisibility()
    }
    
    func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    @objc func saveChanges() {
        let date: Date? = showDatePickerSwitch.isOn ? measurementTime.date : nil
        if let text = textView.text {
            delegate.finishedEditing(ofRow: currentRow, result: (text, date))
        }
        
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction private func showDatePickerSwitchChanged(_ sender: Any) {
        measurementTime.maximumDate = Date()
        measurementTime.isHidden = !showDatePickerSwitch.isOn
    }
}
