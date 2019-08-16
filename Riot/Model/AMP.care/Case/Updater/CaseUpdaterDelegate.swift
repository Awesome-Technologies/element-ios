//
//  CaseUpdaterDelegate.swift
//  Riot
//
//  Created by Marco Festini on 02.08.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

public protocol CaseUpdaterDelegate: class {
    func updateCaseCore(_ core: CaseCore)
    func updatePatient(_ patient: Patient)
    func updateObservation(_ observation: Observation)
}
