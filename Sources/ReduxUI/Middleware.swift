//
//  File.swift
//  
//
//  Created by p.grechikhin on 29.10.2021.
//

import Combine
import Foundation


public enum MiddlewareAction<A: AnyAction, R: RouteType> {
    case performAction(A)
    case performRoute(R)
    case performDeferredAction(AnyDeferredAction<A>)
    case multiple([MiddlewareAction<A, R>])
    case none
}

public protocol Middleware {
    associatedtype S: AnyState
    associatedtype A: AnyAction
    associatedtype R: RouteType
    
    func execute(_ state: S, action: A) -> AnyPublisher<MiddlewareAction<A, R>, Never>?
    
    func eraseToAnyMiddleware() -> AnyMiddleware<S, A, R>
}

public extension Middleware {
    public func eraseToAnyMiddleware() -> AnyMiddleware<S, A, R> {
        return AnyMiddleware(base: self)
    }
}

public class AnyMiddleware<State: AnyState, Action: AnyAction, Route: RouteType>: Middleware {
    public typealias S = State
    public typealias A = Action
    public typealias R = Route
    
    private var _execute: (S, A) -> AnyPublisher<MiddlewareAction<A, R>, Never>?
    
    public init<U: Middleware>(base: U) where U.A == Action, U.S == State, U.R == Route {
        _execute = base.execute(_:action:)
    }
    
    public func execute(_ state: State, action: Action) -> AnyPublisher<MiddlewareAction<Action, Route>, Never>? {
        return _execute(state, action)
    }
    
}
