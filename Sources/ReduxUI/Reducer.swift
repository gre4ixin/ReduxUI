//
//  File.swift
//  
//
//  Created by p.grechikhin on 14.12.2021.
//

import Foundation

//TODO: - Make output dispatch
/// Reducer wrapper protocol for out put dispatch action
public protocol ReducerWrapper {
    associatedtype Action: AnyAction
    
    func performOutput(_ action: Action)
}

public extension ReducerWrapper {
    func performOutput(_ action: Action) { }
}

/// Reducer protocol place for change State
public protocol Reducer: ReducerWrapper {
    associatedtype State: AnyState
    associatedtype Router: AnyRoute
    
    func reduce(_ state: inout State, action: Action, performRoute: @escaping ((_ route: Router) -> Void))
    
    func eraseToAnyReducer() -> AnyReducer<State, Action, Router>
}

/// Default erase type reducer Erasure Type patter for protocol with generic
public extension Reducer {
    func eraseToAnyReducer() -> AnyReducer<State, Action, Router> {
        return AnyReducer(base: self)
    }
}

/// Erase Reducer
public class AnyReducer<_State: AnyState, _Action: AnyAction, _Route: AnyRoute>: Reducer {
    public typealias State = _State
    public typealias Action = _Action
    public typealias Router = _Route
    
    private var _outputHandler: ((Action) -> Void)?
    private var _performReducer: (_ state: inout State, _ action: Action, _ performRoute: @escaping (_ route: Router) -> Void) -> Void
    
    public init<U: Reducer>(base: U) where U.State == _State, U.Action == _Action, U.Router == _Route {
        _performReducer = base.reduce(_:action:performRoute:)
    }
    
    public func reduce(_ state: inout _State, action: _Action, performRoute: @escaping ((_Route) -> Void)) {
        _performReducer(&state, action, performRoute)
    }
    
    public func performOutput(_ action: _Action) {
        _outputHandler?(action)
    }
    
    public func handlingOutputAction(_ handler: @escaping ((Action) -> Void)) {
        self._outputHandler = handler
    }
    
    public func wrapReducer() -> AnyReducerWrapper<Action> {
        return AnyReducerWrapper(base: self)
    }
}

public class AnyReducerWrapper<_A: AnyAction>: ReducerWrapper {
    public typealias Action = _A
    
    private var _performOutput: (Action) -> Void
    
    public init<U: ReducerWrapper>(base: U) where U.Action == _A {
        _performOutput = base.performOutput(_:)
    }
    
    public func performOutput(_ action: _A) {
        _performOutput(action)
    }
    
}
