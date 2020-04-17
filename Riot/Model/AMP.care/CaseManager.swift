//
//  CaseManager.swift
//  Riot
//
//  Created by Marco Festini on 17.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

/// Singleton class to manage all cases. Provides convenience methods.
@objcMembers public class CaseManager: NSObject {
    
    static let shared = CaseManager()
    
    /// Global list of cases. Maps roomId with Case.
    private var cases = [String: Case]()
    
    private override init() { }
    
    /**
     Check if a case already is mapped
     
     - Parameters:
        - roomId: Room Id of the case that is to be checked for.
     */
    func containsCase(for roomId: String) -> Bool {
        return cases.keys.contains(roomId)
    }
    
    /**
     Get, when exists, the case for a given roomId.
     
     - Parameters:
        - roomId: Room Id of the case that is to be updated.
     */
    func getCase(for roomId: String) -> Case? {
        return cases[roomId]
    }
    
    /**
     Add/Update case for the given roomId.
     
     - Parameters:
        - case: case to be mapped with the given room id.
        - room: Room of the case that is to be updated.
     */
    func setCase(_ `case`: Case?, forRoom room: MXRoom!) {
        if let `case` = `case` {
            cases[room.roomId] = `case`
            `case`.updater = CaseUpdater()
            `case`.updater?.delegate = `case`
            `case`.updater?.setRoom(room)
        }
    }
    
    /**
     Convenience function to update obersvation in case.
     
     - Parameters:
        - observation: Updated observation.
        - roomId: Room Id of the case that is to be updated.
    */
    func updateObservation(_ observation: Observation, in roomId: String) {
        cases[roomId]?.setObservation(observation: observation)
    }
}
