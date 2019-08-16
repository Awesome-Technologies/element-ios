//
//  SingleLineEditViewController.swift
//  Riot
//
//  Created by Marco Festini on 18.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class SingleLineEditViewController: UIViewController, EditingView, UITextFieldDelegate {
    weak var delegate: RowEditingDelegate!
    var currentRow: Row!
    
    @IBOutlet weak var measurementTimeLabel: UILabel!
    @IBOutlet weak var measurementTime: UIDatePicker!
    @IBOutlet weak var showDatePickerSwitch: UISwitch!
    
    var restrictToNumbersInput = false {
        didSet {
            if restrictToNumbersInput {
                textfield.keyboardType = .decimalPad
                textfield.clearButtonMode = .never
            } else {
                textfield.keyboardType = .default
                textfield.clearButtonMode = .whileEditing
            }
            updateUnitConstraint(forTextField: textfield)
        }
    }
    
    @IBOutlet weak var unitLabelLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var unitLabel: UILabel!
    @IBOutlet weak var textfield: UITextField!
    
    @objc class func fromNib() -> SingleLineEditViewController {
        let result = SingleLineEditViewController(nibName: String(describing: self), bundle: nil)
        // Force building view hierarchy so all ui bindings are in place
        _ = result.view
        return result
    }
    
    override func viewDidLoad() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveChanges))
        unitLabel.isHidden = true
        
        textfield.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        
        measurementTimeLabel.text = NSLocalizedString("edit_case_measurement_date_label", tableName: "AMPcare", comment: "")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        textfield.becomeFirstResponder()
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
            textfield.text = string
        } else if let quantity = data.value as? Quantity {
            // Disable long press selection
            if let gestureRecognizers = textfield.gestureRecognizers {
                for recognizer in gestureRecognizers where recognizer.isKind(of: UILongPressGestureRecognizer.self) {
                    recognizer.isEnabled = false
                }
            }
            
            textfield.text = quantity.humanReadableValue(withUnit: false)
            if let unit = quantity.unit, !unit.isEmpty {
                unitLabel.text = unit
                unitLabel.isHidden = false
            }
        } else {
            textfield.text = ""
        }
        
        measurementTime.isHidden = !showDate || !showDatePickerSwitch.isOn
        measurementTimeLabel.isHidden = !showDate
        showDatePickerSwitch.isHidden = !showDate
        
        updateUnitConstraint(forTextField: textfield)
    }
    
    func setUnitLabel(_ unit: String) {
        unitLabel.text = unit
        unitLabel.isHidden = false
        
        updateUnitConstraint(forTextField: textfield)
    }
    
    func setPlaceholder(_ string: String?) {
        textfield.placeholder = string
        
        updateUnitConstraint(forTextField: textfield)
    }
    
    @objc func saveChanges() {
        let date: Date? = showDatePickerSwitch.isOn ? measurementTime.date : nil
        
        if let text = textfield.text {
            delegate.finishedEditing(ofRow: currentRow, result: (text, date))
        }
        
        navigationController?.popViewController(animated: true)
    }
    
    func updateUnitConstraint(forTextField textField: UITextField) {
        if restrictToNumbersInput {
            textField.setNeedsLayout()
            textField.layoutIfNeeded()
            var unitOffset: CGFloat = 12
            if let textWidth = textField.attributedText?.size().width, textWidth > 0 {
                unitOffset += textWidth
            } else if let textWidth = textField.attributedPlaceholder?.size().width {
                unitOffset += textWidth
            }
            unitLabelLeadingConstraint.constant = unitOffset
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale.current
        let seperator: String! = numberFormatter.decimalSeparator
        
        let allowedCharacters = CharacterSet.decimalDigits.union(CharacterSet (charactersIn: seperator))
        let characterSet = CharacterSet(charactersIn: string)
        if restrictToNumbersInput && string == seperator && textField.text?.contains(seperator) ?? false {
            return false
        }
        
        return restrictToNumbersInput ? allowedCharacters.isSuperset(of: characterSet) : true
    }
    
    @objc func textFieldDidChange(textField: UITextField) {
        updateUnitConstraint(forTextField: textField)
    }
    
    @IBAction private func showDatePickerSwitchChanged(_ sender: Any) {
        measurementTime.maximumDate = Date()
        measurementTime.isHidden = !showDatePickerSwitch.isOn
    }
}
