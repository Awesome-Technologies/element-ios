//
//  WeakSet.swift
//  Riot
//
//  Created by Marco Festini on 02.08.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

public final class WeakSet<T> {
    private let _mutex = NSObject()
    fileprivate var _contents = NSMutableSet()
    
    /**
     Returns the number of references currently in the set.
     
     Includes potential nil references, so this number >= allObjects.count
     */
    public var count: Int {
        return _contents.count
    }
    
    public init() {
        
    }
    
    public init<S: Sequence>(_ sequence: S) where S.Iterator.Type == T {
        for element in sequence {
            _contents.add(WeakReference(element))
        }
    }
    
    /**
     Adds the specified object to the set.
     */
    public func add(_ object: T) {
        return synchronized(_mutex) {
            add(WeakReference(object))
        }
    }
    
    /**
     Adds the object to which the specified reference points to the set.
     */
    
    public func add(_ reference: WeakReference<T>) {
        return synchronized(_mutex) {
            //Remove the existing ref first, this is delicate, because a lingering reference might exist
            //for which the reference is nil, but it is still in the set nonetheless
            _contents.remove(reference)
            _contents.add(reference)
        }
    }
    
    /**
     Removes the specified object from the set.
     */
    public func remove(_ object: T) {
        return synchronized(_mutex) {
            remove(WeakReference(object))
        }
    }
    
    /**
     Removes the object to which the specified reference points from this set.
     */
    public func remove(_ reference: WeakReference<T>) {
        return synchronized(_mutex) {
            _contents.remove(reference)
        }
    }
    
    /**
     Whether or not this set contains the specified object.
     */
    public func contains(_ object: T) -> Bool {
        return synchronized(_mutex) {
            let ref = WeakReference(object)
            return contains(ref) && ref.target != nil
        }
    }
    
    /**
     Whether or not this set contains the specified reference.
     */
    public func contains(_ reference: WeakReference<T>) -> Bool {
        return synchronized(_mutex) {
            return _contents.contains(reference)
        }
    }
    
    /**
     Returns all non-nil references as an ordinary array.
     */
    public var allObjects: [T] {
        //The map function operates on any sequence
        //Because of the way we defined our iterator, only non-nil objects will be returned.
        return synchronized(_mutex) {
            return self.map {
                return $0
            }
        }
    }
    
    /**
     Method to remove all nil references from the set.
     
     Returns true if references were removed, false otherwise.
     */
    public func compress() -> Bool {
        return synchronized(_mutex) {
            var removedElement = false
            if let copy = _contents.copy() as? NSSet {
                for element in copy {
                    if let ref = element as? WeakReference<T>, ref.target != nil {
                        //Keep
                    } else {
                        //Remove
                        _contents.remove(element)
                        removedElement = true
                    }
                }
            }
            return removedElement
        }
    }
}

extension WeakSet: Sequence {
    public typealias Iterator = WeakSetIterator<T>
    
    public func makeIterator() -> Iterator {
        //Should be synchronized because of the copy
        return synchronized(_mutex) {
            let copy = (_contents.copy() as? NSSet)!
            return WeakSetIterator(copy.makeIterator())
        }
    }
}

public final class WeakSetIterator<T>: IteratorProtocol {
    
    private var iterator: NSFastEnumerationIterator
    
    fileprivate init(_ iterator: NSFastEnumerationIterator) {
        self.iterator = iterator
    }
    
    public func next() -> T? {
        while let obj = iterator.next() {
            if let ref = obj as? WeakReference<T>, let target = ref.target {
                return target
            }
        }
        return nil
    }
}

import Foundation

/**
 Swift equivalence of @synchronized.
 */
@discardableResult
public func synchronized<T>(_ object: Any, block: () throws -> T) rethrows -> T {
    objc_sync_enter(object)
    defer {
        objc_sync_exit(object)
    }
    return try block()
}
