//
//  Component.swift
//  Riot
//
//  Created by Marco Festini on 15.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

public class Component: NSObject {
    var value: Quantity?
    var code: CodableConcept!
    
    init?(content: [String: Any]) {
        super.init()
        
        if let quantityDict = content["valueQuantity"] as? [String: Any] {
            value = Quantity(content: quantityDict)
        }
        
        if let concept = content["code"] as? [String: Any] {
            code = CodableConcept(content: concept)
        } else {
            return nil
        }
    }
    
    func jsonRepresentation() -> [String: Any] {
        var dict = [String: Any]()
        
        if let value = value {
            dict["valueQuantity"] = value.jsonRepresentation()
        }
        
        dict["code"] = code.jsonRepresentation()
        
        return dict
    }
}
