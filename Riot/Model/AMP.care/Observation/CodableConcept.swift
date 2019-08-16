//
//  CodableConcept.swift
//  Riot
//
//  Created by Marco Festini on 15.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

public class CodableConcept: NSObject {
    var codingArray = [Coding]()
    var text: String?
    
    init?(content: [String: Any]) {
        super.init()
        if let codeDict = content["coding"] as? [[String: Any]] {
            for code in codeDict {
                if let coding = Coding(content: code) {
                    codingArray.append(coding)
                }
            }
        }
        
        text = content["text"] as? String
        
        if text == nil && codingArray.isEmpty {
            return nil
        }
    }
    
    func jsonRepresentation() -> [String: Any] {
        var dict = [String: Any]()
        
        var codesDict = [[String: Any]]()
        for coding in codingArray {
            codesDict.append(coding.jsonRepresentation())
        }
        dict["coding"] = codesDict
        
        if let text = text {
            dict["text"] = text
        }
        
        return dict
    }
}
