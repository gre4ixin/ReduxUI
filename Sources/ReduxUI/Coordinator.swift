//
//  File.swift
//  
//
//  Created by p.grechikhin on 14.12.2021.
//

import Foundation

public protocol Coordinator {
    associatedtype R: RouteType
    
    func perform(_ route: R)
    func eraseToAnyCoordinator() -> AnyCoordinator<R>
}

public extension Coordinator {
    func eraseToAnyCoordinator() -> AnyCoordinator<R> {
        return AnyCoordinator(base: self)
    }
}

public class AnyCoordinator<_R: RouteType>: Coordinator {
    public typealias R = _R
    
    private var _perform: (R) -> Void
    
    public init<U: Coordinator>(base: U) where U.R == _R {
        _perform = base.perform(_:)
    }
    
    public func perform(_ route: _R) {
        _perform(route)
    }
    
}
