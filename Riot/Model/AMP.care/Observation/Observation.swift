//
//  Observation.swift
//  Riot
//
//  Created by Marco Festini on 15.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

/// Observation of a patient modeled after [HL7 FHIR](http://hl7.org/fhir/observation.html).
public class Observation: NSObject {
    /// Supported identifiers describing the type of observation.
    /// See the individual cases for the required fields when using `init(content:)`.
    public enum Identifier: String {
        /**
         Oxygen saturation.
         
         Using `init(content:)`, this identifier is only valid when:
         - content["valueQuanity"] is of type `Quantity`.
         */
        case oxygen
        
        /**
         Heart rate.
         
         Using `init(content:)`, this identifier is only valid when:
         - content["valueQuanity"] is of type `Quantity`.
         */
        case heartRate = "heart-rate"
        
        /**
         Glucose.
         
         Using `init(content:)`, this identifier is only valid when:
         - content["valueQuanity"] is of type `Quantity`.
         */
        case glucose
        
        /**
         Body Temperature.
         
         Using `init(content:)`, this identifier is only valid when:
         - content["valueQuanity"] is of type `Quantity`.
         */
        case bodyTemperature = "body-temperature"
        
        /**
         Blood pressure.
         
         Using `init(content:)`, this identifier is only valid when:
         - content["component"] is an array of `Quantity`, holding Coding for `Coding.Loinc.systolicBloodPressure` and `Coding.Loinc.diastolicBloodPressure`.
         */
        case bloodPressure = "blood-pressure"
        
        /**
         Last defecation.
         
         Using `init(content:)`, this identifier is only valid when:
         - content["effectiveDateTime"] can be parsed to `Date`. See `dateFormatters` property.
         */
        case lastDefecation = "last-defecation"
        
        /**
         Misc.
         
         Using `init(content:)`, this identifier is only valid when:
         - content["valueString"] is of type `String`.
         */
        case misc
        
        /**
         Body weight.
         
         Using `init(content:)`, this identifier is only valid when:
         - content["valueQuanity"] is of type `Quantity`.
         */
        case bodyWeight = "body-weight"
        
        /**
         Responsiveness.
         
         Using `init(content:)`, this identifier is only valid when:
         - content["valueString"] is of type `String`.
         */
        case responsiveness
        
        /**
         Pain.
         
         Using `init(content:)`, this identifier is only valid when:
         - content["valueString"] is of type `String`.
         */
        case pain
        
        /// Used if no other identifier makes sense, or when no valid identifier was passed.
        case undefined
        
        /// Localized string using rawValue
        func localized() -> String {
            return NSLocalizedString(self.rawValue, tableName: "AMPcare", comment: "")
        }
        
        /// The associated default unit where applicable, otherwise empty string.
        func defaultUnit() -> String {
            switch self {
            case .oxygen:
                return "%"
                
            case .bodyWeight:
                return "kg"
                
            case .bodyTemperature:
                return "C"
                
            case .glucose:
                return "mg/dl"
                
            case .heartRate:
                return "beats/minute"
                
            case .bloodPressure:
                return "mmHg"
                
            default: return ""
            }
        }
    }
    
    var humanReadableEffectiveDateTime: String {
        if let date = effectiveDateTime {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            dateFormatter.doesRelativeDateFormatting = true
            return dateFormatter.string(from: date)
        }
        return "-"
    }
    
    var humanReadableValue: String {
        guard let identifier = id else { return "-" }
        switch identifier {
        case .oxygen, .heartRate, .glucose, .bodyTemperature, .bodyWeight:
            if let result = value as? Quantity {
                return result.humanReadableValue
            }
            
        case .bloodPressure:
            let valueForLoinc: (Coding.Loinc) -> Quantity? = { loinc in
                guard let components = self.components else {
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
                return "\(systolic.humanReadableValue) / \(diastolic.humanReadableValue)"
            }
            
        case .lastDefecation:
            return humanReadableEffectiveDateTime
            
        case .misc, .responsiveness, .pain:
            if let result = value as? String {
                return result
            }
            
        default: break
        }
        return "-"
    }
    
    /// List of valid `DateFormatter` objects. Modeled after [DateTime](http://hl7.org/fhir/datatypes.html#dateTime) in HL7 FHIR.
    let dateFormatters: [DateFormatter] = {
        return Observation.dateFormatters
    }()
    
    /// List of valid `DateFormatter` objects. Modeled after [DateTime](http://hl7.org/fhir/datatypes.html#dateTime) in HL7 FHIR.
    static let dateFormatters: [DateFormatter] = {
        var array = [DateFormatter]()
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        array.append(dateFormatter)
        
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        array.append(dateFormatter)
        
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        array.append(dateFormatter)
        
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        array.append(dateFormatter)
        
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        array.append(dateFormatter)
        
        return array
    }()
    
    let id: Identifier!
    let resourceType = "Observation"
    
    /// Relevant time for the observation.
    private(set) var effectiveDateTime: Date?
    
    /// Who was observed?
    var subject: String?
    
    /// Meta information about the observation.
    var meta: String?
    
    /// Type of observation.
    var code: CodableConcept?
    
    /// Classification of observation.
    var category: CodableConcept?
    
    /// Component results.
    var components: [Component]?
    
    /// Actual result of observation. Can be nil. See `Observation.Identifier` for more information.
    var value: Any?
    
    init(_ id: Identifier) {
        self.id = id
    }
    
    convenience init(_ idString: String) {
        self.init(Identifier(rawValue: idString) ?? .undefined)
    }
    
    /**
     Initializer to create an Observation object given a `[String: Any]` dictionary.
     
     The passed `[String: Any]` dictionary will be parsed to extract information that will be used to fill this objects properties.
     A valid dictionary looks as follows:
     ```
     var content = ["id": "responsiveness",
     "resourceType": "Observation",
     "subject": "Patient/Hannelore Maier",
     "effectiveDateTime": "2018-10-12T00:00:00",
     "valueString": "Ist Ansprechbar."
     ] as [String: Any]
     ```
     
     - Parameters:
        - content: A dictionary that will be parsed to fill the objects properties.
     
     - Returns: An Observation object or nil when content does not hold the required fields for the given identifier.
     */
    convenience init? (content: [String: Any]) {
        // Check for a valid identifier
        guard let idString = content["id"] as? String,
            let rType = content["resourceType"] as? String else { return nil }
        
        self.init(idString)
        
        if rType != resourceType {
            return nil
        }
        
        if let dateString = content["effectiveDateTime"] as? String {
            setEffectiveDateTime(to: dateString)
        }
        
        subject = content["subject"] as? String
        
        if let metaDict = content["meta"] as? [String: Any] {
            meta = metaDict["profile"] as? String
        }
        
        if let concepts = content["code"] as? [String: Any] {
            code = CodableConcept(content: concepts)
        }
        
        if let concepts = content["category"] as? [String: Any] {
            category = CodableConcept(content: concepts)
        }
        
        if let componentDict = content["component"] as? [[String: Any]] {
            components = [Component]()
            for component in componentDict {
                if let c = Component(content: component) {
                    components?.append(c)
                }
            }
        }
        
        if let valueQuantityDict = content["valueQuantity"] as? [String: Any] {
            value = Quantity(content: valueQuantityDict)
        } else {
            value = content["valueString"] as? String
        }
        
        if !isValid() {
            return nil
        }
    }
    
    /**
     Checks all `Component` objects in `components` for a given `Coding.Loinc` enum.
     
     - Parameters:
        - loinc: Loinc code to check all components for.
     
     - Returns: true, if a component with the given code was found, false if not.
     */
    func componentHas(code loinc: Coding.Loinc) -> Bool {
        if let array = components {
            for component in array {
                for codeElement in component.code.codingArray where codeElement.code == loinc.rawValue {
                    return true
                }
            }
        }
        return false
    }
    
    /// Validating the current object based on its identifier. See `Observation.Identifier` for more information.
    func isValid() -> Bool {
        guard let identifier = id else { return false }
        switch identifier {
        case .oxygen, .heartRate, .glucose, .bodyTemperature, .bodyWeight:
            if !(value is Quantity) {
                return false
            }
        case .bloodPressure:
            if !(componentHas(code: .systolicBloodPressure) && componentHas(code: .diastolicBloodPressure)) {
                return false
            }
        case .lastDefecation:
            if !(effectiveDateTime != nil) {
                return false
            }
        case .misc, .responsiveness, .pain:
            if !(value is String) {
                return false
            }
        case .undefined: return false
        }
        
        return true
    }
    
    /**
     Convenience function to set the `effectiveDateTime` property.
     
     See `dateFormatters` for valid formats.
     
     - Parameters:
        - dateString: String to be parsed.
     */
    func setEffectiveDateTime(to dateString: String) {
        for dateFormatter in dateFormatters {
            if let newDate = dateFormatter.date(from: dateString) {
                effectiveDateTime = newDate
            }
        }
        if effectiveDateTime == nil {
            print("[Observation.\(#function)] Not a valid date string. \(dateString)")
        }
    }
    
    /// Returns a `[String: Any]` dictionary representation of the current object that can be serialized into json.
    func jsonRepresentation() -> [String: Any] {
        var dict = [String: Any]()
        
        dict["id"] = id.rawValue
        dict["resourceType"] = resourceType
        
        if let subject = subject {
            dict["subject"] = subject
        }
        
        if let meta = meta {
            dict["meta"] = ["profile": meta]
        }
        
        if let code = code {
            dict["code"] = code.jsonRepresentation()
        }
        
        if let category = category {
            dict["category"] = category.jsonRepresentation()
        }
        
        if let components = components {
            var componentDict = [[String: Any]]()
            
            for component in components {
                componentDict.append(component.jsonRepresentation())
            }
            
            dict["component"] = componentDict
        }
        
        if let date = effectiveDateTime, let dateFormatter = dateFormatters.first {
            dict["effectiveDateTime"] = dateFormatter.string(from: date)
        }
        
        if let value = value as? String {
            dict["valueString"] = value
        } else if let value = value as? Quantity {
            dict["valueQuantity"] = value.jsonRepresentation()
        }
        
        return dict
    }
    
    // MARK: - Convenience functions to create observations
    
    static func bodyWeightObservation(weight: Float, patient: Patient? = nil, date: Date? = nil) -> Observation? {
        var content = [
            "category": [
                "coding": [[
                    "code": "vital-signs",
                    "display": "Vital Signs",
                    "system": "http://hl7.org/fhir/observation-category"
                    ]],
                "text": "Vital Signs"
            ],
            "code": [
                "coding": [[
                    "code": "29463-7",
                    "display": "Body Weight",
                    "system": "http://loinc.org"
                    ]],
                "text": "Body Weight"
            ],
            "id": Identifier.bodyWeight.rawValue,
            "meta": [
                "profile": "http://hl7.org/fhir/StructureDefinition/vitalsigns"
            ],
            "resourceType": "Observation",
            "valueQuantity": [
                "code": "kg",
                "system": "http://unitsofmeasure.org",
                "unit": "kg",
                "value": weight]
            ] as [String: Any]
        
        if let name = patient?.name {
            content["subject"] = "Patient/\(name)"
        }
        
        if let dateFormatter = dateFormatters.first, let effectiveDateTime = date {
            content["effectiveDateTime"] = dateFormatter.string(from: effectiveDateTime)
        }
        
        return Observation(content: content)
    }
    
    static func oxygenObservation(saturation: Int, patient: Patient? = nil, date: Date? = nil) -> Observation? {
        var content = [
            "category": [
                "coding": [[
                    "code": "vital-signs",
                    "display": "Vital Signs",
                    "system": "http://hl7.org/fhir/observation-category"
                    ]],
                "text": "Vital Signs"
            ],
            "code": [
                "coding": [[
                    "code": "59408-5",
                    "display": "Oxygen saturation in Arterial blood by Pulse oximetry",
                    "system": "http://loinc.org"
                    ]],
                "text": "Oxygen saturation"
            ],
            "id": Identifier.oxygen.rawValue,
            "meta": [
                "profile": "http://hl7.org/fhir/StructureDefinition/vitalsigns"
            ],
            "resourceType": "Observation",
            "valueQuantity": [
                "code": "%",
                "system": "http://unitsofmeasure.org",
                "unit": "%",
                "value": saturation]
            ] as [String: Any]
        
        if let name = patient?.name {
            content["subject"] = "Patient/\(name)"
        }
        
        if let dateFormatter = dateFormatters.first, let effectiveDateTime = date {
            content["effectiveDateTime"] = dateFormatter.string(from: effectiveDateTime)
        }
        
        return Observation(content: content)
    }
    
    static func glucoseObservation(glucose: Int, patient: Patient? = nil, date: Date? = nil) -> Observation? {
        var content = [
            "category": [
                "coding": [[
                    "code": "vital-signs",
                    "display": "Vital Signs",
                    "system": "http://hl7.org/fhir/observation-category"
                    ]],
                "text": "Vital Signs"
            ],
            "code": [
                "coding": [[
                    "code": "15074-8",
                    "display": "Glucose [Milligramm/volume] in Blood",
                    "system": "http://loinc.org"
                    ]],
                "text": "Glucose"
            ],
            "id": Identifier.glucose.rawValue,
            "meta": [
                "profile": "http://hl7.org/fhir/StructureDefinition/vitalsigns"
            ],
            "resourceType": "Observation",
            "valueQuantity": [
                "code": "mg/dl",
                "system": "http://unitsofmeasure.org",
                "unit": "mg/dl",
                "value": glucose]
            ] as [String: Any]
        
        if let name = patient?.name {
            content["subject"] = "Patient/\(name)"
        }
        
        if let dateFormatter = dateFormatters.first, let effectiveDateTime = date {
            content["effectiveDateTime"] = dateFormatter.string(from: effectiveDateTime)
        }
        
        return Observation(content: content)
    }
    
    static func bodyTemperatureObservation(temp: Float, patient: Patient? = nil, date: Date? = nil) -> Observation? {
        var content = [
            "category": [
                "coding": [[
                    "code": "vital-signs",
                    "display": "Vital Signs",
                    "system": "http://hl7.org/fhir/observation-category"
                    ]],
                "text": "Vital Signs"
            ],
            "code": [
                "coding": [[
                    "code": "8310-5",
                    "display": "Body temperature",
                    "system": "http://loinc.org"
                    ]],
                "text": "Body temperature"
            ],
            "id": Identifier.bodyTemperature.rawValue,
            "meta": [
                "profile": "http://hl7.org/fhir/StructureDefinition/vitalsigns"
            ],
            "resourceType": "Observation",
            "valueQuantity": [
                "code": "Cel",
                "system": "http://unitsofmeasure.org",
                "unit": "C",
                "value": temp]
            ] as [String: Any]
        
        if let name = patient?.name {
            content["subject"] = "Patient/\(name)"
        }
        
        if let dateFormatter = dateFormatters.first, let effectiveDateTime = date {
            content["effectiveDateTime"] = dateFormatter.string(from: effectiveDateTime)
        }
        
        return Observation(content: content)
    }
    
    static func heartRateObservation(beats: Int, patient: Patient? = nil, date: Date? = nil) -> Observation? {
        var content = [
            "category": [
                "coding": [[
                "code": "vital-signs",
                "display": "Vital Signs",
                "system": "http://hl7.org/fhir/observation-category"
                ]],
                "text": "Vital Signs"
            ],
            "code": [
                "coding": [[
                "code": "8867-4",
                "display": "Heart rate",
                "system": "http://loinc.org"
                ]],
                "text": "Heart rate"
            ],
            "id": Identifier.heartRate.rawValue,
            "meta": [
                "profile": "http://hl7.org/fhir/StructureDefinition/vitalsigns"
            ],
            "resourceType": "Observation",
            "valueQuantity": [
                "code": "/min",
                "system": "http://unitsofmeasure.org",
                "unit": "beats/minute",
                "value": beats]
            ] as [String: Any]
        
        if let name = patient?.name {
            content["subject"] = "Patient/\(name)"
        }
        
        if let dateFormatter = dateFormatters.first, let effectiveDateTime = date {
            content["effectiveDateTime"] = dateFormatter.string(from: effectiveDateTime)
        }
        
        return Observation(content: content)
    }
    
    static func responsivenessObservation(desc: String, patient: Patient? = nil, date: Date? = nil) -> Observation? {
        var content = [
            "id": Identifier.responsiveness.rawValue,
            "resourceType": "Observation",
            "valueString": desc
            ] as [String: Any]
        
        if let name = patient?.name {
            content["subject"] = "Patient/\(name)"
        }
        
        if let dateFormatter = dateFormatters.first, let effectiveDateTime = date {
            content["effectiveDateTime"] = dateFormatter.string(from: effectiveDateTime)
        }
        
        return Observation(content: content)
    }
    
    static func painObservation(desc: String, patient: Patient? = nil, date: Date? = nil) -> Observation? {
        var content = [
            "code": [
                "coding": [[
                    "code": "28319-2",
                    "display": "Pain status",
                    "system": "http://loinc.org"
                    ]],
                "text": "Pain status"
            ],
            "id": Identifier.pain.rawValue,
            "resourceType": "Observation",
            "valueString": desc
            ] as [String: Any]
        
        if let name = patient?.name {
            content["subject"] = "Patient/\(name)"
        }
        
        if let dateFormatter = dateFormatters.first, let effectiveDateTime = date {
            content["effectiveDateTime"] = dateFormatter.string(from: effectiveDateTime)
        }
        
        return Observation(content: content)
    }
    
    static func lastDefecationObservation(date: Date, patient: Patient? = nil) -> Observation? {
        var content = [
            "id": Identifier.lastDefecation.rawValue,
            "resourceType": "Observation"
            ] as [String: Any]
        
        if let name = patient?.name {
            content["subject"] = "Patient/\(name)"
        }
        
        if let dateFormatter = dateFormatters.first {
            content["effectiveDateTime"] = dateFormatter.string(from: date)
        }
        
        return Observation(content: content)
    }
    
    static func miscObservation(desc: String, patient: Patient? = nil, date: Date? = nil) -> Observation? {
        var content = [
            "id": Identifier.misc.rawValue,
            "resourceType": "Observation",
            "valueString": desc
            ] as [String: Any]
        
        if let name = patient?.name {
            content["subject"] = "Patient/\(name)"
        }
        
        if let dateFormatter = dateFormatters.first, let effectiveDateTime = date {
            content["effectiveDateTime"] = dateFormatter.string(from: effectiveDateTime)
        }
        
        return Observation(content: content)
    }
    
    static func bloodPressureObservation(systolic: Int, diastolic: Int, patient: Patient? = nil, date: Date? = nil) -> Observation? {
        var content = [
            "category": [
                "coding": [[
                    "code": "vital-signs",
                    "display": "Vital Signs",
                    "system": "http://hl7.org/fhir/observation-category"
                    ]],
                "text": "Vital Signs"
            ],
            "code": [
                "coding": [[
                    "code": "85354-9",
                    "display": "Blood pressure panel with all children optional",
                    "system": "http://loinc.org"
                    ]],
                "text": "Blood pressure systolic & diastolic"
            ],
            "component": [[
                "code": [
                    "coding": [[
                        "code": "8480-6",
                        "display": "Systolic blood pressure",
                        "system": "http://loinc.org"
                        ]],
                    "text": "Systolic blood pressure"
                ],
                "valueQuantity": [
                    "code": "mm[Hg]",
                    "system": "http://unitsofmeasure.org",
                    "unit": "mmHg",
                    "value": systolic
                ]
                ], [
                    "code": [
                        "coding": [[
                            "code": "8462-4",
                            "display": "Diastolic blood pressure",
                            "system": "http://loinc.org"
                            ]],
                        "text": "Diastolic blood pressure"
                    ],
                    "valueQuantity": [
                        "code": "mm[Hg]",
                        "system": "http://unitsofmeasure.org",
                        "unit": "mmHg",
                        "value": diastolic
                    ]
                ]
            ],
            "id": Identifier.bloodPressure.rawValue,
            "meta": [
                "profile": "http://hl7.org/fhir/StructureDefinition/vitalsigns"
            ],
            "resourceType": "Observation"
            ] as [String: Any]
        
        if let name = patient?.name {
            content["subject"] = "Patient/\(name)"
        }
        
        if let effectiveDateTime = date, let dateFormatter = dateFormatters.first {
            content["effectiveDateTime"] = dateFormatter.string(from: effectiveDateTime)
        }
        
        return Observation(content: content)
    }
}
