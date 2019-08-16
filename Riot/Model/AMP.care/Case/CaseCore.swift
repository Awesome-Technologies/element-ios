//
//  CaseCore.swift
//  MatrixKit
//
//  Created by Marco Festini on 12.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import Foundation

/// The core of a case holding general information.
public class CaseCore: NSObject {
    /// The title of the case.
    var title: String!
    /// The severity of the case.
    var severity: Case.Severity!
    /// The requester of the case.
    var requester: String!
    
    /// A note describing the initital situation about the case.
    var note: String?
    
    override public var description: String {
        return title + "\n" + requester + "\n" + severity.rawValue
    }
    
    /**
     Initializer to create a CaseCore object.
     
     - Parameters:
        - title: The title of the case
        - severity: The severity of the case
        - requester: The requester of the case
     
     - Returns: A valid CaseCore object
     */
    init(title: String, severity: Case.Severity, requester: String) {
        self.title = title
        self.severity = severity
        self.requester = requester
    }
    
    /**
     Initializer to create a CaseCore object given a `[String: Any]` dictionary.
     
     The passed `[String: Any]` dictionary will be parsed to extract information that will be used to fill this objects properties.
     A valid dictionary looks as follows:
     ```
     var content = ["title": "Kopfwunde bei Frau Müller",
         "note": "Frau Müller ist eine Treppe hinuntergestürzt und hat sich dabei den Kopf gestoßen. Ich sende Ihnen Bilder der Wunde.",
         "severity": "info",
         "requester": [
            "reference": "Pflegeheim/Maier"]
         ] as [String: Any]
     ```
     
     - Important:
     `title` is a required key of type `String`.
     `requester` is a required key of type `[String: String]` with a key `reference`.
     `severity` is a required key of type `String`.
     
     - Parameters:
        - content: A dictionary that will be parsed to fill the objects properties.
     
     - Returns: A valid CaseCore object.
     */
    convenience init?(content: [String: Any]) {
        guard let title = content["title"] as? String else { return nil }
        
        guard let requesterDict = content["requester"] as? [String: String] else { return nil }
        guard let reference = requesterDict["reference"] else { return nil }
        
        guard let severityString = content["severity"] as? String else { return nil }
        guard let severity = Case.Severity(rawValue: severityString) else { return nil }
        
        self.init(title: title, severity: severity, requester: reference)
        
        note = content["note"] as? String
    }
    
    /// Returns a `[String: Any]` dictionary representation of the current object that can be serialized into json.
    func jsonRepresentation() -> [String: Any] {
        var dict = ["title": title, "severity": severity.rawValue, "requester": ["reference": requester]] as [String: Any]
        
        if let note = note {
            dict["note"] = note
        }
        
        return dict
    }
}
