//
//  File.swift
//  
//
//  Created by p.grechikhin on 29.10.2021.
//

import Combine
import Foundation


/// Returnable type from middleware
public enum MiddlewareAction<Action: AnyAction, Router: AnyRoute> {
    case performAction(Action)
    case performRoute(Router)
    case performDeferredAction(AnyDeferredAction<Action>)
    case multiple([MiddlewareAction<Action, Router>])
    case none
}

/// Middleware protocol for process your action in background thread
public protocol Middleware {
    associatedtype State: AnyState
    associatedtype Action: AnyAction
    associatedtype Router: AnyRoute
    
    /// Return `AnyPublisher` if you want process current action or `nil` if you don't want process it
    /// - Returns: `AnyPublisher` with `MiddlewareAction`
    func execute(_ state: State, action: Action) -> AnyPublisher<MiddlewareAction<Action, Router>, Never>?
    
    /// `TypeErasure`
    func eraseToAnyMiddleware() -> AnyMiddleware<State, Action, Router>
}

public extension Middleware {
    /// Default Implementation
    func eraseToAnyMiddleware() -> AnyMiddleware<State, Action, Router> {
        return AnyMiddleware(base: self)
    }
}

/// TypeErasure Middleware
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

#if swift(>=5.5)

public protocol AsyncMiddleware {
    associatedtype State: AnyState
    associatedtype Action: AnyAction
    associatedtype Router: AnyRoute
    
    func execute(_ state: State, action: Action) async -> MiddlewareAction<Action, Router>?
    
    func eraseToAnyMiddleware() -> AnyAsyncMiddleware<State, Action, Router>
}

public extension AsyncMiddleware {
    func eraseToAnyMiddleware() -> AnyAsyncMiddleware<State, Action, Router> {
        return AnyAsyncMiddleware(base: self)
    }
}

public class AnyAsyncMiddleware<State: AnyState, Action: AnyAction, RouteType: AnyRoute>: AsyncMiddleware {
    public typealias State = State
    public typealias Action = Action
    public typealias Router = RouteType
    
    private var privateExecute: (State, Action) async -> MiddlewareAction<Action, Router>?
    
    public init<U: AsyncMiddleware>(base: U) where U.Action == Action, U.State == State, U.Router == RouteType {
        privateExecute = base.execute(_:action:)
    }
    
    public func execute(_ state: State, action: Action) async -> MiddlewareAction<Action, RouteType>? {
        return await privateExecute(state, action)
    }
    
}

#endif
