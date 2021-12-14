//
//  File.swift
//  
//
//  Created by p.grechikhin on 29.10.2021.
//

import Foundation
import Combine

public protocol AnyAction { }

public protocol DeferredAction {
    associatedtype A: AnyAction
    func observe() -> AnyPublisher<A, Never>?
    
    func eraseToAnyDeferredAction() -> AnyDeferredAction<A>
}

public extension DeferredAction {
    func eraseToAnyDeferredAction() -> AnyDeferredAction<A> {
        return AnyDeferredAction<A>(base: self)
    }
}

public class AnyDeferredAction<ActionType: AnyAction>: DeferredAction {
    public typealias A = ActionType
    
    private let _observe: () -> AnyPublisher<ActionType, Never>?
    
    public init<U: DeferredAction>(base: U) where U.A == ActionType {
        _observe = base.observe
    }
    
    public func observe() -> AnyPublisher<ActionType, Never>? {
        return _observe()
    }
    
}
