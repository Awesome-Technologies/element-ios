//
//  Coding.swift
//  Riot
//
//  Created by Marco Festini on 15.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

public class Coding: NSObject {
    enum Loinc: String {
        case systolicBloodPressure = "8480-6"
        case diastolicBloodPressure = "8462-4"
        case heartRate = "8867-4"
        case oxygen = "59408-5"
        case glucose = "15074-8"
        case bloodTemperature = "8310-5"
        case bodyWeight = "29463-7"
        case pain = "28319-2"
        
        case undefined = "0"
    }
    
    var version: String?
    var display: String?
    var system: String?
    
    var asLoinc: Loinc {
        if let c = code {
            return Loinc(rawValue: c) ?? .undefined
        }
        return .undefined
    }
    
    private var _code: String?
    var code: String? {
        get {
            return _code
        }
        set {
            do {
                guard let value = newValue else { return }
                let range = NSRange(location: 0, length: value.utf16.count)
                let regex = try NSRegularExpression(pattern: "[^\\s]+(\\s[^\\s]+)*")
                if regex.firstMatch(in: value, options: [], range: range) != nil {
                    _code = value
                } else {
                    print("[Coding] Trying to set code. Didn't match regular expression. See (http://hl7.org/fhir/datatypes.html#code)")
                }
            } catch let error {
                print("[Coding] Trying to set code. \(error.localizedDescription)")
            }
        }
    }
    
    init?(content: [String: Any]) {
        super.init()
        code = content["code"] as? String
        display = content["display"] as? String
        system = content["system"] as? String
        version = content["version"] as? String
        
        if code == nil && display == nil && system == nil && version == nil {
            return nil
        }
    }
    
    func jsonRepresentation() -> [String: Any] {
        var dict = [String: Any]()
        
        if let version = version {
            dict["version"] = version
        }
        
        if let display = display {
            dict["display"] = display
        }
        
        if let system = system {
            dict["system"] = system
        }
        
        if let code = code {
            dict["code"] = code
        }
        
        return dict
    }
}
