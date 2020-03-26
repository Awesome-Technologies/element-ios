//
//  CaseUpdater.swift
//  Riot
//
//  Created by Marco Festini on 02.08.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

public class CaseUpdater: NSObject {
    weak var delegate: CaseUpdaterDelegate!
    
    private var listener: Any!
    
    private var room: MXRoom! {
        willSet {
            unregister()
        }
        didSet {
            pullData()
            register()
        }
    }
    
    public func setRoom(_ room: MXRoom!) {
        self.room = room
    }
    
    private func pullData() {
        room.state { state in
            guard let state = state else { return }
            
            let caseEvent = state.stateEvents(with: Case.EventType.case.mxEventType())?.last
            self.handleEvent(caseEvent, andState: state)
            
            let patientEvent = state.stateEvents(with: Case.EventType.patient.mxEventType())?.last
            self.handleEvent(patientEvent, andState: state)
        }
        
        let manager = MXKRoomDataSourceManager.sharedManager(forMatrixSession: room.mxSession)
        manager?.roomDataSource(forRoom: room.roomId, create: true, onComplete: { dataSource in
            guard let dataSource = dataSource else { return }
            
            dataSource.paginate(100, direction: MXTimelineDirection.backwards.identifier, onlyFromStore: false, success: { _ in
                
                if let eventEnumerator = self.room.enumeratorForStoredMessagesWithType(in: [Case.EventType.observation.rawValue]) {
                    while let event = eventEnumerator.nextEvent {
                        self.handleEvent(event, withContent: event.content)
                    }
                }
                
                dataSource.timeline.resetPagination()
                
            }, failure: { error in
                print("\(#function) Error paginating")
                if let error = error {
                    print(error.localizedDescription)
                }
            })
        })
    }
    
    private func register() {
        guard let room = room else { return }
        
        let events = [Case.EventType.case.rawValue, Case.EventType.patient.rawValue, Case.EventType.observation.rawValue]
        
        listener = room.listen(toEventsOfTypes: events) { (event, direction, prevState) in
            if let event = event, let prevState = prevState {
                self.handleEvent(event, andState: prevState)
            }
        }
    }
    
    private func handleEvent(_ event: MXEvent!, andState prevState: MXRoomState!) {
        guard let content = prevState?.content(of: event) else { return }
        
        handleEvent(event, withContent: content)
    }
    
    private func handleEvent(_ event: MXEvent!, withContent content: [String: Any]!) {
        guard event != nil, content != nil else { return }
        
        if event.type == Case.EventType.case.rawValue, let caseCore = CaseCore(content: content) {
            delegate?.updateCaseCore(caseCore)
        } else if event.type == Case.EventType.patient.rawValue, let patient = Patient(content: content) {
            delegate?.updatePatient(patient)
        } else if event.type == Case.EventType.observation.rawValue, let observation = Observation(content: content) {
            delegate?.updateObservation(observation)
        }
    }
    
    private func unregister() {
        guard room != nil, listener != nil else { return }
        
        room.removeListener(listener)
        listener = nil
    }
    
    deinit {
        unregister()
    }
}
