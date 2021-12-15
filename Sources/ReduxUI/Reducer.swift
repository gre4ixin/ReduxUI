//
//  File.swift
//  
//
//  Created by p.grechikhin on 14.12.2021.
//

import Foundation

public protocol ReducerWrapper {
    associatedtype A: AnyAction
    
    func performOutput(_ action: A)
}

public extension ReducerWrapper {
    func performOutput(_ action: A) { }
}

public protocol Reducer: ReducerWrapper {
    associatedtype S: AnyState
    associatedtype R: RouteType
    
    func reduce(_ state: inout S, action: A, performRoute: @escaping ((_ route: R) -> Void))
    
    func eraseToAnyReducer() -> AnyReducer<S, A, R>
}

public extension Reducer {
    func eraseToAnyReducer() -> AnyReducer<S, A, R> {
        return AnyReducer(base: self)
    }
}

public class AnyReducer<_State: AnyState, _Action: AnyAction, _Route: RouteType>: Reducer {
    public typealias S = _State
    public typealias A = _Action
    public typealias R = _Route
    
    private var _outputHandler: ((A) -> Void)?
    private var _performReducer: (_ state: inout S, _ action: A, _ performRoute: @escaping (_ route: R) -> Void) -> Void
    
    public init<U: Reducer>(base: U) where U.S == _State, U.A == _Action, U.R == _Route {
        _performReducer = base.reduce(_:action:performRoute:)
    }
    
    public func reduce(_ state: inout _State, action: _Action, performRoute: @escaping ((_Route) -> Void)) {
        _performReducer(&state, action, performRoute)
    }
    
    public func performOutput(_ action: _Action) {
        _outputHandler?(action)
    }
    
    public func handlingOutputAction(_ handler: @escaping ((A) -> Void)) {
        self._outputHandler = handler
    }
    
    public func wrapReducer() -> AnyReducerWrapper<A> {
        return AnyReducerWrapper(base: self)
    }
}

public class AnyReducerWrapper<_A: AnyAction>: ReducerWrapper {
    typealias A = _A
    
    private var _performOutput: (A) -> Void
    
    public init<U: ReducerWrapper>(base: U) where U.A == _A {
        _performOutput = base.performOutput(_:)
    }
    
    public func performOutput(_ action: _A) {
        _performOutput(action)
    }
    
}
