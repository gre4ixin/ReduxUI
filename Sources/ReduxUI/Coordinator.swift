//
//  File.swift
//  
//
//  Created by p.grechikhin on 14.12.2021.
//

import Foundation

public protocol Coordinator {
    associatedtype Router: AnyRoute
    
    func perform(_ route: Router)
    func eraseToAnyCoordinator() -> AnyCoordinator<Router>
}

public extension Coordinator {
    func eraseToAnyCoordinator() -> AnyCoordinator<Router> {
        return AnyCoordinator(base: self)
    }
}

public class AnyCoordinator<_R: AnyRoute>: Coordinator {
    public typealias Router = _R
    
    private var _perform: (Router) -> Void
    
    public init<U: Coordinator>(base: U) where U.Router == _R {
        _perform = base.perform(_:)
    }
    
    public func perform(_ route: _R) {
        _perform(route)
    }
    
}
