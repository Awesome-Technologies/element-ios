//
//  Observable.swift
//  Riot
//
//  Created by Marco Festini on 02.08.19.
//  Copyright © 2019 behindmedia. All rights reserved.
//

import UIKit

/**
 Protocol describing an object which may be observed by associated observers.
 
 The observable weakly references its observers.
 */
public protocol Observable: class {
    
    /**
     Type of observer: which will be a protocol defining the notifications that may be sent.
     */
    associatedtype Observer
    
    /**
     Array containing the currently alive observers (not yet deallocated).
     */
    var observers: [Observer] { get }
    
    /**
     Adds an observer.
     */
    func addObserver(_ observer: Observer) -> ObserverToken
    
    /**
     Removes an observer.
     */
    func removeObserver(_ observer: Observer)
    
    /**
     Notifies all observers with the specified closure.
     */
    func notifyObservers(_ closure: (Observer) -> Void)
}

private var observerSetKey = "com.behindmedia.common.core.Observable.observerSet"

public extension Observable {
    
    private var observerSet: WeakSet<Observer> {
        return associatedValue(for: self, key: &observerSetKey, defaultValue: WeakSet<Observer>())
    }
    
    var observers: [Observer] {
        return observerSet.allObjects
    }
    
    func addObserver(_ observer: Observer) -> ObserverToken {
        observerSet.add(observer)
        
        //Explicitly use a weak reference to the observer, because the observer itself may be nil already if called
        //during deallocation
        let ref = WeakReference(observer)
        let result = ObserverToken(removalBlock: { [weak self] in self?.removeObserver(ref) })
        
        return result
    }
    
    func removeObserver(_ observer: Observer) {
        observerSet.remove(observer)
    }
    
    func notifyObservers(_ closure: (Observer) -> Void) {
        for observer in observers {
            closure(observer)
        }
    }
    
    private func removeObserver(_ reference: WeakReference<Observer>) {
        observerSet.remove(reference)
    }
}

import ObjectiveC

public func associatedValue<T>(for object: Any, key: UnsafeRawPointer, defaultValue: @autoclosure () -> T) -> T {
    return synchronized(object) {
        if let nonNilValue = objc_getAssociatedObject(object, key) {
            guard let typeSafeValue = nonNilValue as? T else {
                fatalError("Unexpected: different kind of value already exists for key '\(key)': \(nonNilValue)")
            }
            return typeSafeValue
        } else {
            let newValue = defaultValue()
            objc_setAssociatedObject(object, key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            assert(objc_getAssociatedObject(object, key) != nil, "Associated values are not supported for object: \(object)")
            assert(objc_getAssociatedObject(object, key) is T, "Associated value could not be cast back to specified type: \(String(describing: T.self))")
            return newValue
        }
    }
}

/**
 Token which uniquely defines a registered observation and may subsequently be used to remove the observation.
 */
public struct ObserverToken: CustomStringConvertible {
    
    private let removalBlock: () -> Void
    private let identifier = UUID()
    
    fileprivate init(removalBlock: @escaping () -> Void) {
        self.removalBlock = removalBlock
    }
    
    /**
     Deregisters (removes) the observer from the observable
     */
    public func deregister() {
        removalBlock()
    }
    
    public var description: String {
        return "ObserverToken(\(self.identifier))"
    }
}
