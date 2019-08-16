//
//  CaseListener.swift
//  Riot
//
//  Created by Marco Festini on 02.08.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

public protocol CaseListener {
    func updatedCaseCore()
    func updatedPatient()
    func updatedObservations()
}

// Giving protocol function a default implementation to make them "optional"
public extension CaseListener {
    func updatedCaseCore() {}
    func updatedPatient() {}
    func updatedObservations() {}
}
