//
//  WeakReference.swift
//  Riot
//
//  Created by Marco Festini on 02.08.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

/**
 Wrapper around an object reference to prevent it being strongly retained.
 */
public final class WeakReference<T>: NSObject {
    
    /**
     Target object, which may be nil if deallocated.
     */
    public var target: T? {
        return _targetObj as? T
    }
    
    /**
     Internal weak reference.
     */
    private weak var _targetObj: AnyObject?
    
    /**
     Internal storage of memory address.
     */
    private let _memoryAddress: Int
    
    public init(_ target: T) {
        self._memoryAddress = unsafeBitCast(target as AnyObject, to: Int.self)
        self._targetObj = target as AnyObject
        super.init()
    }
    
    public override var hash: Int {
        return _memoryAddress
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        if let ref = object as? WeakReference {
            return self._memoryAddress == ref._memoryAddress
        }
        return false
    }
}
