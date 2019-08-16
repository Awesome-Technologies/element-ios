//
//  VitalsViewController.swift
//  Riot
//
//  Created by Marco Festini on 24.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class VitalsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, EditingView, RowEditingDelegate {
    weak var delegate: RowEditingDelegate!
    var currentRow: Row!
    
    @IBOutlet weak var tableView: UITableView!
    
    var sections = [Section]()
    var observations = [Row: Observation]()
    
    @objc class func fromNib() -> VitalsViewController {
        let vc = VitalsViewController(nibName: String(describing: self), bundle: nil)
        // Force building view hierarchy so all ui bindings are in place
        _ = vc.view
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(TwoLabelTableViewCell.nib(), forCellReuseIdentifier: TwoLabelTableViewCell.defaultReuseIdentifier())
        
        tableView.tableFooterView = UIView()
        
        var array = [Row]()
        array.append(.bodyWeight)
        array.append(.bodyTemperature)
        array.append(.glucose)
        array.append(.oxygen)
        sections.append(Section(rows: array, title: ""))
        
        array = [Row]()
        array.append(.bloodPressure)
        array.append(.heartRate)
        sections.append(Section(rows: array, title: NSLocalizedString("case_detail_section_heart", tableName: "AMPcare", comment: "")))
    }
    
    func addObservation(_ observation: Observation?) {
        guard let observation = observation, let row = Row(rawValue: observation.id.rawValue) else { return }
        
        observations[row] = observation
    }
    
    // MARK: - RowEditingDelegate
    
    func finishedEditing(ofRow row: Row, result: Any?) {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale.current
        
        switch row {
        case .bodyWeight:
            if let result = result as? (text: String, date: Date?), let number = numberFormatter.number(from: result.text)?.floatValue {
                observations[.bodyWeight] = Observation.bodyWeightObservation(weight: number, date: result.date)
            } else {
                observations.removeValue(forKey: .bodyWeight)
            }
            
        case .bodyTemperature:
            if let result = result as? (text: String, date: Date?), let number = numberFormatter.number(from: result.text)?.floatValue {
                observations[.bodyTemperature] = Observation.bodyTemperatureObservation(temp: number, date: result.date)
            } else {
                observations.removeValue(forKey: .bodyTemperature)
            }
            
        case .glucose:
            if let result = result as? (text: String, date: Date?), let number = numberFormatter.number(from: result.text)?.intValue {
                observations[.glucose] = Observation.glucoseObservation(glucose: number, date: result.date)
            } else {
                observations.removeValue(forKey: .glucose)
            }
            
        case .bloodPressure:
            if let result = result as? (systolicStr: String, diastolicStr: String, date: Date?),
                let systolic = numberFormatter.number(from: result.systolicStr)?.intValue,
                let diastolic = numberFormatter.number(from: result.diastolicStr)?.intValue {
                observations[.bloodPressure] = Observation.bloodPressureObservation(systolic: systolic, diastolic: diastolic, date: result.date)
            } else {
                observations.removeValue(forKey: .bloodPressure)
            }
            
        case .heartRate:
            if let result = result as? (text: String, date: Date?), let number = numberFormatter.number(from: result.text)?.intValue {
                observations[.heartRate] = Observation.heartRateObservation(beats: number, date: result.date)
            } else {
                observations.removeValue(forKey: .heartRate)
            }
            
        case .oxygen:
            if let result = result as? (text: String, date: Date?), let number = numberFormatter.number(from: result.text)?.intValue {
                observations[.oxygen] = Observation.oxygenObservation(saturation: number, date: result.date)
            } else {
                observations.removeValue(forKey: .oxygen)
            }
            
        default: break
        }
        
        delegate.finishedEditing(ofRow: row, result: observations[row])
        
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        
        cell = tableView.dequeueReusableCell(withIdentifier: "Default")
        if cell == nil {
            cell = UITableViewCell(style: .value1, reuseIdentifier: "Default")
        }
        
        let row = sections[indexPath.section].rows[indexPath.row]
        let type = row.observationIdentifier()
        
        cell?.textLabel?.text = type?.localized()
        if let observation = observations[row] {
            cell.detailTextLabel?.text = observation.humanReadableValue
        }
        if cell == nil {
            cell = UITableViewCell(style: .value1, reuseIdentifier: "Default")
        }
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var vc: (UIViewController & EditingView)!
        
        let row = sections[indexPath.section].rows[indexPath.row]
        
        switch row {
        case .bodyWeight:
            let viewController = SingleLineEditViewController.fromNib()
            viewController.setUnitLabel(Observation.Identifier.bodyWeight.defaultUnit())
            viewController.setInitialData((observations[.bodyWeight]?.value, observations[.bodyWeight]?.effectiveDateTime), showDate: true)
            viewController.restrictToNumbersInput = true
            vc = viewController
            
        case .bodyTemperature:
            let viewController = SingleLineEditViewController.fromNib()
            viewController.setUnitLabel(Observation.Identifier.bodyTemperature.defaultUnit())
            viewController.setInitialData((observations[.bodyTemperature]?.value, observations[.bodyTemperature]?.effectiveDateTime), showDate: true)
            viewController.restrictToNumbersInput = true
            vc = viewController
            
        case .glucose:
            let viewController = SingleLineEditViewController.fromNib()
            viewController.setUnitLabel(Observation.Identifier.glucose.defaultUnit())
            viewController.setInitialData((observations[.glucose]?.value, observations[.glucose]?.effectiveDateTime), showDate: true)
            viewController.restrictToNumbersInput = true
            vc = viewController
            
        case .bloodPressure:
            let viewController = TwoIntegerEditViewController.fromNib()
            
            viewController.setUnitLabels((Observation.Identifier.bloodPressure.defaultUnit(), Observation.Identifier.bloodPressure.defaultUnit()))
            
            let placeholder: (String, String) = (NSLocalizedString("systolic_placeholder", tableName: "AMPcare", comment: ""), NSLocalizedString("diastolic_placeholder", tableName: "AMPcare", comment: ""))
            var didSet = false
            if let bloodPressure = observations[.bloodPressure] {
                let valueForLoinc: (Coding.Loinc) -> Quantity? = { loinc in
                    guard let components = bloodPressure.components else {
                        return nil
                    }
                    for component in components {
                        for coding in component.code.codingArray where coding.asLoinc == loinc {
                            return component.value
                        }
                    }
                    return nil
                }
                if let systolic = valueForLoinc(.systolicBloodPressure), let diastolic = valueForLoinc(.diastolicBloodPressure) {
                    didSet = true
                    viewController.setInitialData(((systolic, diastolic), bloodPressure.effectiveDateTime), showDate: true)
                    viewController.setPlaceholder(withData: placeholder)
                }
            }
            if !didSet {
                viewController.setInitialData((nil, nil), showDate: false)
            }
            viewController.setPlaceholder(withData: placeholder)
            vc = viewController
            
        case .heartRate:
            let viewController = SingleLineEditViewController.fromNib()
            viewController.setUnitLabel(Observation.Identifier.heartRate.defaultUnit())
            viewController.setInitialData((observations[.heartRate]?.value, observations[.heartRate]?.effectiveDateTime), showDate: true)
            viewController.restrictToNumbersInput = true
            vc = viewController
            
        case .oxygen:
            let viewController = SingleLineEditViewController.fromNib()
            viewController.setUnitLabel(Observation.Identifier.oxygen.defaultUnit())
            viewController.setInitialData((observations[.oxygen]?.value, observations[.oxygen]?.effectiveDateTime), showDate: true)
            viewController.restrictToNumbersInput = true
            vc = viewController
            
        default: break
        }
        
        if vc != nil {
            vc.currentRow = row
            vc.delegate = self
            vc.title = NSLocalizedString("edit_case_\(row.rawValue)_title", tableName: "AMPcare", comment: "")
            self.show(vc, sender: self)
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
