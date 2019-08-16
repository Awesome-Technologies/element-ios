//
//  CaseTableViewConstants.swift
//  Riot
//
//  Created by Marco Festini on 24.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import Foundation

public enum Row: String {
    case created
    case patient
    case recipient
    case requester
    case severity
    case title
    case note
    case anamnesis
    case vitals
    case pictures
    case bodyWeight = "body-weight"
    case bodyTemperature = "body-temperature"
    case glucose
    case bloodPressure = "blood-pressure"
    case heartRate = "heart-rate"
    case oxygen
    case responsiveness
    case pain
    case misc
    case lastDefecation = "last-defecation"
    
    func isObservation() -> Bool {
        switch self {
        case .oxygen, .bodyWeight, .bodyTemperature, .glucose, .bloodPressure, .heartRate, .responsiveness, .patient, .pain, .misc, .lastDefecation:
            return true
            
        default:
            return false
        }
    }
    
    func observationIdentifier() -> Observation.Identifier? {
        switch self {
        case .oxygen, .bodyWeight, .bodyTemperature, .glucose, .bloodPressure, .heartRate, .responsiveness, .patient, .pain, .misc, .lastDefecation:
            return Observation.Identifier(rawValue: self.rawValue)
            
        default:
            return nil
        }
    }
}

public struct Section {
    var rows: [Row]
    var title: String
}
