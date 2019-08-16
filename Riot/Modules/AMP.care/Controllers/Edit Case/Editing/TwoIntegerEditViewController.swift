//
//  TwoIntegerEditViewController.swift
//  Riot
//
//  Created by Marco Festini on 25.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class TwoIntegerEditViewController: UIViewController, EditingView, UITextFieldDelegate {
    weak var delegate: RowEditingDelegate!
    var currentRow: Row!
    
    @IBOutlet weak var firstUnitLabel: UILabel!
    @IBOutlet weak var firstTextfield: UITextField!
    @IBOutlet weak var secondTextfield: UITextField!
    @IBOutlet weak var secondUnitLabel: UILabel!
    @IBOutlet weak var measurementTimeLabel: UILabel!
    @IBOutlet weak var measurementTime: UIDatePicker!
    @IBOutlet weak var showDatePickerSwitch: UISwitch!
    @IBOutlet weak var firstUnitLabelLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var secondUnitLabelLeadingConstraint: NSLayoutConstraint!
    
    @objc class func fromNib() -> TwoIntegerEditViewController {
        let result = TwoIntegerEditViewController(nibName: String(describing: self), bundle: nil)
        // Force building view hierarchy so all ui bindings are in place
        _ = result.view
        return result
    }
    
    override func viewDidLoad() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveChanges))
        
        firstTextfield.keyboardType = .decimalPad
        firstTextfield.clearButtonMode = .never
        secondTextfield.keyboardType = .decimalPad
        secondTextfield.clearButtonMode = .never
        
        // Disable long press selection
        if let first = firstTextfield.gestureRecognizers, let second = secondTextfield.gestureRecognizers {
            let gestureRecognizers = first + second
            for recognizer in gestureRecognizers where recognizer.isKind(of: UILongPressGestureRecognizer.self) {
                recognizer.isEnabled = false
            }
        }
        
        firstTextfield.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        secondTextfield.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        
        measurementTimeLabel.text = NSLocalizedString("edit_case_measurement_date_label", tableName: "AMPcare", comment: "")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        firstTextfield.becomeFirstResponder()
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
        
        if let data = data.value as? (quantity1: Quantity, quantity2: Quantity), let value1 = data.quantity1.value, let value2 = data.quantity2.value {
            firstTextfield.text = String(format: "%.0f", value1)
            secondTextfield.text = String(format: "%.0f", value2)
            
            if let firstUnit = data.quantity1.unit {
                firstUnitLabel.text = firstUnit
            }
            if let secondUnit = data.quantity2.unit {
                secondUnitLabel.text = secondUnit
            }
        } else {
            firstTextfield.text = ""
            secondTextfield.text = ""
        }
        
        measurementTime.isHidden = !showDate || !showDatePickerSwitch.isOn
        measurementTimeLabel.isHidden = !showDate
        showDatePickerSwitch.isHidden = !showDate
        
        updateUnitConstraint(forTextField: firstTextfield)
        updateUnitConstraint(forTextField: secondTextfield)
    }
    
    func setPlaceholder(withData data: Any?) {
        if let data = data as? (value1: String, value2: String) {
            firstTextfield.placeholder = data.value1
            secondTextfield.placeholder = data.value2
        }
        
        updateUnitConstraint(forTextField: firstTextfield)
        updateUnitConstraint(forTextField: secondTextfield)
    }
    
    func setUnitLabels(_ units: (first: String, second: String)) {
        firstUnitLabel.text = units.first
        secondUnitLabel.text = units.second
        
        updateUnitConstraint(forTextField: firstTextfield)
        updateUnitConstraint(forTextField: secondTextfield)
    }
    
    @objc func saveChanges() {
        let date: Date? = showDatePickerSwitch.isOn ? measurementTime.date : nil
        delegate.finishedEditing(ofRow: currentRow, result: (firstTextfield.text, secondTextfield.text, date))
        
        navigationController?.popViewController(animated: true)
    }
    
    func updateUnitConstraint(forTextField textField: UITextField) {
        var unitOffset: CGFloat = 12
        if let textWidth = textField.attributedText?.size().width, textWidth > 0 {
            unitOffset += textWidth
        } else if let textWidth = textField.attributedPlaceholder?.size().width {
            unitOffset += textWidth
        }
        
        if textField == firstTextfield {
            firstUnitLabelLeadingConstraint.constant = unitOffset
        } else {
            secondUnitLabelLeadingConstraint.constant = unitOffset
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale.current
        let seperator: String! = numberFormatter.decimalSeparator
        
        let allowedCharacters = CharacterSet.decimalDigits.union(CharacterSet (charactersIn: seperator))
        let characterSet = CharacterSet(charactersIn: string)
        if string == seperator && textField.text?.contains(seperator) ?? false {
            return false
        }
        
        return allowedCharacters.isSuperset(of: characterSet)
    }
    
    @objc func textFieldDidChange(textField: UITextField) {
        updateUnitConstraint(forTextField: textField)
    }
    
    @IBAction private func showDatePickerSwitchChanged(_ sender: Any) {
        measurementTime.maximumDate = Date()
        measurementTime.isHidden = !showDatePickerSwitch.isOn
    }
}
