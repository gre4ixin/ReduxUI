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
    associatedtype Action: AnyAction
    func observe() -> AnyPublisher<Action, Never>?
    
    func eraseToAnyDeferredAction() -> AnyDeferredAction<Action>
}

public extension DeferredAction {
    func eraseToAnyDeferredAction() -> AnyDeferredAction<Action> {
        return AnyDeferredAction<Action>(base: self)
    }
}

public class AnyDeferredAction<ActionType: AnyAction>: DeferredAction {
    public typealias Action = ActionType
    
    private let _observe: () -> AnyPublisher<ActionType, Never>?
    
    public init<U: DeferredAction>(base: U) where U.Action == ActionType {
        _observe = base.observe
    }
    
    public func observe() -> AnyPublisher<ActionType, Never>? {
        return _observe()
    }
    
}
