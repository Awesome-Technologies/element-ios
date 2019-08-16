//
//  Patient.swift
//  MatrixSDK
//
//  Created by Marco Festini on 12.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import Foundation

/// Representation of basic patient data
public class Patient: NSObject {
    
    /// Pateints gender enum
    public enum Gender: String {
        case male
        case female
        case other
        /// Unknown gender case. Used if no gender was defined.
        case unknown
        
        /// Localized string
        func localized() -> String {
            return NSLocalizedString("patient_gender_\(self.rawValue)", tableName: "AMPcare", comment: "")
        }
    }
    
    /// Full name
    var name: String!
    
    /// Gender. Can be nil.
    var gender: Gender?
    
    /// Date of birth. Can be nil.
    var birthDate: Date?
    
    var age: Int {
        if let birthDate = birthDate {
            let calendar = Calendar(identifier: .gregorian)
            let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
            if let age = ageComponents.year {
                return age
            }
        }
        return 0
    }
    
    /// Managing organization of the patient. Can be nil.
    var managingOrganization: String?
    
    /// General practitioner of the patient. Can be nil.
    var generalPractitioner: String?
    
    override public var description: String {
        return "Patient: " + name
    }
    
    /**
     Initializer to create a Patient object.
     
     - Parameters:
        - name: Name of the patient.
     
     - Returns: A valid Patient object.
     */
    init(name: String) {
        self.name = name
    }
    
    /**
     Initializer to create a Patient object given a `[String: Any]` dictionary.
     
     The passed `[String: Any]` dictionary will be parsed to extract information that will be used to fill this objects properties.
     A valid dictionary looks as follows:
     ```
     var content = ["name": "Hannelore Maier",
     "gender": "female",
     "birthDate": "1932-04-21",
     "managingOrganization": [
        "reference": "Pflegeheim"
     ],
     "generalPractitioner": [
        "reference": "Arzt"
     ] as [String: Any]
     ```
     
     - Important:
     `name` is a required key of type `String`.
     
     - Parameters:
        - content: A dictionary that will be parsed to fill the objects properties.
     
     - Returns: A valid Patient object.
     */
    convenience init?(content: [String: Any]) {
        if let name = content["name"] as? String {
            self.init(name: name)
        } else {
            return nil
        }
        
        if let genderString = content["gender"] as? String {
            gender = Gender(rawValue: genderString) ?? .unknown
        }
        
        if let birthDateString = content["birthDate"] as? String, !birthDateString.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd"
            birthDate = dateFormatter.date(from: birthDateString)
        }
        
        if let dict = content["managingOrganization"] as? [String: Any] {
            managingOrganization = dict["reference"] as? String
        }
        if let dict = content["generalPractitioner"] as? [String: Any] {
            generalPractitioner = dict["reference"] as? String
        }
    }
    
    /// Returns a `[String: Any]` dictionary representation of the current object that can be serialized into json.
    func jsonRepresentation() -> [String: Any] {
        var dict = ["name": name] as [String: Any]
        
        if let gender = gender {
            dict["gender"] = gender.rawValue
        }
        
        if let birthDate = birthDate {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            dict["birthDate"] = dateFormatter.string(from: birthDate)
        }
        
        if let managingOrganization = managingOrganization {
            dict["managingOrganization"] = ["reference": managingOrganization]
        }
        
        if let generalPractitioner = generalPractitioner {
            dict["generalPractitioner"] = ["reference": generalPractitioner]
        }
        
        return dict
    }
}
