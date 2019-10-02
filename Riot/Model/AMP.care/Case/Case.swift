//
//  Case.swift
//  Riot
//
//  Created by Marco Festini on 17.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

/// Holder class to combine information about a single case.
public class Case: NSObject, Observable, CaseUpdaterDelegate, NSCopying {
    
    public typealias Observer = CaseListener
    public var updater: CaseUpdater?
    
    /// Types of Case events. Used as MXEventTypeString when sending events in Matrix.
    enum EventType: String {
        // Backticks to allow keywords as name
        case `case` = "care.amp.case"
        case patient = "care.amp.patient"
        case observation = "care.amp.observation"
        case done = "care.amp.done"
        
        /// Return a MXEventType enum object used in MXEvent.
        func mxEventType() -> MXEventType {
            return MXEventType.custom(rawValue)
        }
    }

    /// Urgency of a case.
    public enum Severity: String {
        case info
        case request
        case urgent
        case critical
        
        /// Localized string
        func localized() -> String {
            return NSLocalizedString("case_severity_" + self.rawValue, tableName: "AMPcare", comment: "")
        }
        
        /// Mapped UIColor for a given severity.
        func color() -> UIColor {
            switch self {
            case .info:
                return UIColor(red: 0.27, green: 0.67, blue: 0.95, alpha: 1.0)
            case .request:
                return UIColor(red: 0.15, green: 0.87, blue: 0.51, alpha: 1.0)
            case .urgent:
                return UIColor(red: 0.97, green: 0.79, blue: 0.19, alpha: 1.0)
            case .critical:
                return UIColor(red: 0.92, green: 0.23, blue: 0.35, alpha: 1.0)
            }
        }
    }
    
    /// General information about the case.
    var caseCore: CaseCore? {
        didSet {
            notifyObservers { observer in
                observer.updatedCaseCore()
            }
        }
    }
    
    /// The patient the case is about.
    var patient: Patient? {
        didSet {
            notifyObservers { observer in
                observer.updatedPatient()
            }
        }
    }
    
    /// Latest observation for each `Observation.Identifier`.
    private(set) var observations = [Observation.Identifier: Observation]() {
        didSet {
            notifyObservers { observer in
                observer.updatedObservations()
            }
        }
    }
    
    public init(withCore caseCore: CaseCore? = nil, andPatient patient: Patient? = nil) {
        self.caseCore = caseCore
        self.patient = patient
    }
    
    /**
     Update the observation array with a new observation.
     
     The `observations` property holds the latest observations for each `Observation.Identifier`.
     This function puts the given observation into the dictionary or replaces an existing observation with the same identifier.
     
     - Parameters:
        - observation: Observation object that will be put into the observation array property.
     */
    func setObservation(observation: Observation?) {
        guard let observation = observation else { return }
        observations[observation.id] = observation
    }
    
    /**
     Remove observation for a given `Identifier`.
     
     The `observations` property holds the latest observations for each `Observation.Identifier`.
     This function removes the observation with the given identifier from the dictionary if it exists.
     
     - Parameters:
        - identifier: Observation object that will be put into the observation array property.
     */
    func removeObservation(withIdentifier identifier: Observation.Identifier) {
        observations.removeValue(forKey: identifier)
    }
    
    // MARK: - CaseUpdateDelegate
    
    public func updateCaseCore(_ core: CaseCore) {
        self.caseCore = core
    }
    
    public func updatePatient(_ patient: Patient) {
        self.patient = patient
    }
    
    public func updateObservation(_ observation: Observation) {
        setObservation(observation: observation)
    }
    
    // MARK: - NSCopying
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = Case(withCore: caseCore, andPatient: patient)
        for observation in observations {
            copy.setObservation(observation: Observation(content: observation.value.jsonRepresentation()))
        }
        return copy
    }
}
