//
//  File.swift
//  
//
//  Created by p.grechikhin on 29.10.2021.
//

import Combine
import Foundation


public enum MiddlewareAction<Action: AnyAction, Router: AnyRoute> {
    case performAction(Action)
    case performRoute(Router)
    case performDeferredAction(AnyDeferredAction<Action>)
    case multiple([MiddlewareAction<Action, Router>])
    case none
}

public protocol Middleware {
    associatedtype State: AnyState
    associatedtype Action: AnyAction
    associatedtype Router: AnyRoute
    
    func execute(_ state: State, action: Action) -> AnyPublisher<MiddlewareAction<Action, Router>, Never>?
    
    func eraseToAnyMiddleware() -> AnyMiddleware<State, Action, Router>
}

public extension Middleware {
    func eraseToAnyMiddleware() -> AnyMiddleware<State, Action, Router> {
        return AnyMiddleware(base: self)
    }
}

public class AnyMiddleware<State: AnyState, Action: AnyAction, Route: AnyRoute>: Middleware {
    public typealias State = State
    public typealias Action = Action
    public typealias Router = Route
    
    private var _execute: (State, Action) -> AnyPublisher<MiddlewareAction<Action, Router>, Never>?
    
    public init<U: Middleware>(base: U) where U.Action == Action, U.State == State, U.Router == Route {
        _execute = base.execute(_:action:)
    }
    
    public func execute(_ state: State, action: Action) -> AnyPublisher<MiddlewareAction<Action, Route>, Never>? {
        return _execute(state, action)
    }
    
}
