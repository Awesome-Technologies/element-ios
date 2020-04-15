//
//  PatientEditViewController.swift
//  Riot
//
//  Created by Marco Festini on 18.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class PatientEditViewController: UIViewController, EditingView {
    var currentRow: Row!
    weak var delegate: RowEditingDelegate!
    
    @IBOutlet weak var textfield: UITextField!
    
    @IBOutlet weak var genderLabel: UILabel!
    @IBOutlet weak var genderSegmentControl: UISegmentedControl!
    
    @IBOutlet weak var birthDateLabel: UILabel!
    @IBOutlet weak var birthDatePicker: UIDatePicker!
    
    private var initialBirthDate: Date?
    
    let genders: [Patient.Gender] = [.male, .female, .other, .unknown]
    
    @objc class func fromNib() -> PatientEditViewController {
        let result = PatientEditViewController(nibName: String(describing: self), bundle: nil)
        // Force building view hierarchy so all ui bindings are in place
        _ = result.view
        return result
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genderLabel.text = NSLocalizedString("patient_edit_gender_label", tableName: "AMPcare", comment: "")
        birthDateLabel.text = NSLocalizedString("patient_edit_birthDate_label", tableName: "AMPcare", comment: "")
        
        genderSegmentControl.removeAllSegments()
        for gender in genders {
            genderSegmentControl.insertSegment(withTitle: gender.localized(), at: genderSegmentControl.numberOfSegments, animated: false)
        }
        genderSegmentControl.selectedSegmentIndex = -1
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveChanges))
        
        birthDatePicker.maximumDate = Date()
    }
    
    func setInitialData(_ data: (value: Any?, date: Date?)) {
        if let patient = data.value as? Patient {
            textfield.text = patient.name
            if let gender = patient.gender, let index = genders.firstIndex(of: gender) {
                genderSegmentControl.selectedSegmentIndex = index
            }
            if let birthDate = patient.birthDate {
                initialBirthDate = birthDate
                birthDatePicker.date = birthDate
            }
        }
    }
    
    func setPlaceholder(_ string: String?) {
        textfield.placeholder = string
    }
    
    @objc func saveChanges() {
        guard let name = textfield.text, !name.isEmpty else {
            navigationController?.popViewController(animated: true)
            return
        }
        let patient = Patient(name: name)
        if genderSegmentControl.selectedSegmentIndex != UISegmentedControl.noSegment {
            patient.gender = genders[genderSegmentControl.selectedSegmentIndex]
        } else {
            patient.gender = .unknown
        }
        
        let calendar = Calendar.current
        let newBirthDate = birthDatePicker.date
        let newBirthDateComponents = calendar.dateComponents([.day, .month, .year], from: newBirthDate)
        let currentComponents = calendar.dateComponents([.day, .month, .year], from: Date())
        
        if let patientBirthDate = initialBirthDate {
            
            let patientComponents = calendar.dateComponents([.day, .month, .year], from: patientBirthDate)
            
            if patientComponents != newBirthDateComponents {
                patient.birthDate = birthDatePicker.date
            }
        } else if newBirthDateComponents != currentComponents {
            patient.birthDate = birthDatePicker.date
        }
        delegate.finishedEditing(ofRow: currentRow, result: patient)
        
        navigationController?.popViewController(animated: true)
    }
}
