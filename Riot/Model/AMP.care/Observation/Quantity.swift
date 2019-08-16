//
//  Quantity.swift
//  Riot
//
//  Created by Marco Festini on 15.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

public class Quantity: NSObject, NSCopying {
    
    var value: Float?
    var unit: String?
    var system: String?
    
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
                    print("[Quantity] Trying to set code. Didn't match regular expression. See (http://hl7.org/fhir/datatypes.html#code)")
                }
            } catch let error {
                print("[Quantity] Trying to set code. \(error.localizedDescription)")
            }
        }
    }
    
    init?(content: [String: Any]) {
        super.init()
        
        if let floatValue = content["value"] as? Float {
            value = floatValue
        } else if let intValue = content["value"] as? Int {
            value = Float(intValue)
        } else if let stringValue = content["value"] as? String {
            value = Float(stringValue)
        }
        
        unit = content["unit"] as? String
        system = content["system"] as? String
        code = content["code"] as? String
        
        if value == nil {
            return nil
        }
    }
    
    func jsonRepresentation() -> [String: Any] {
        var dict = [String: Any]()
        
        if let value = value {
            dict["value"] = value
        }
        
        if let unit = unit {
            dict["unit"] = unit
        }
        
        if let system = system {
            dict["system"] = system
        }
        
        if let code = code {
            dict["code"] = code
        }
        
        return dict
    }
    
    var humanReadableValue: String {
        return humanReadableValue()
    }
    
    func humanReadableValue(withUnit showUnit: Bool = true) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale.current
        numberFormatter.maximumFractionDigits = 1
        numberFormatter.alwaysShowsDecimalSeparator = false
        
        if let value = value, let valueStr = numberFormatter.string(from: NSNumber(value: value)) {
            if showUnit, let unit = unit, !unit.isEmpty {
                return "\(valueStr) \(unit)"
            } else {
                return valueStr
            }
        }
        
        return "-"
    }
    
    // MARK: - NSCopying
    
    public func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
}
