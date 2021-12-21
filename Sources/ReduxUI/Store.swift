//
//  File.swift
//  
//
//  Created by p.grechikhin on 29.10.2021.
//

import Combine
import SwiftUI
import Foundation

public typealias CombineBag = Set<AnyCancellable>

public class Store<State: AnyState, Action: AnyAction, Router: AnyRoute>: ObservableObject {
    
    ///  Change State from
    ///
    ///     public func dispatch(_ action: Action)
    @Published public private(set) var state: State
    
    public var outputReducer: AnyReducerWrapper<Action> {
        return reducer.wrapReducer()
    }
    
    public typealias StoreReducer = AnyReducer<State, Action, Router>
    public typealias PerformRoute = (_ route: Router) -> Void
    
    private let reducer: AnyReducer<State, Action, Router>
    private var performRoute: PerformRoute!
    private(set) var middlewares: [AnyMiddleware<State, Action, Router>] = []
    private var middlewareCancellables = CombineBag()
    private var coordinator: AnyCoordinator<Router>
    private let queue =  DispatchQueue(label: "redux.serial.queue")
    private var lock = os_unfair_lock_s()
    
    /// Init store with initial state value if you have to use DI
    /// - Parameters:
    ///   - initialState: your State
    ///   - coordinator:
    ///   - reducer: AnyReducer
    public init(initialState: State, coordinator: AnyCoordinator<Router>, reducer: StoreReducer) {
        self.state = initialState
        self.coordinator = coordinator
        self.reducer = reducer
        self.performRoute = { [weak self] route in
            guard let self = self else { return }
            self.route(route)
        }
        
        reducer.handlingOutputAction { [weak self] outputAction in
            guard let self = self else { return }
            self.dispatch(outputAction)
        }
    }
    
    public func add(_ middleware: AnyMiddleware<State, Action, Router>) {
        middlewares.append(middleware)
    }
    
    /// Calling dispatch with action for processing State
    /// - Parameter action: AnyAction
    public func dispatch(_ action: Action) {
        os_unfair_lock_lock(&lock)
        reducer.reduce(&state, action: action, performRoute: performRoute)
        os_unfair_lock_unlock(&lock)
        
        
        /// Check if any middlewares can perform current action
        for mw in middlewares {
            guard let future = mw.execute(state, action: action) else { return }
            
            future
                .subscribe(on: queue)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [weak self] middlewareAction in
                    guard let self = self else { return }
                    switch middlewareAction {
                    case .none: break
                    case .performAction(let action):
                        self.dispatch(action)
                    case .performRoute(let route):
                        self.route(route)
                    case .performDeferredAction(let anyDeferredAction):
                        self.runDeferredAction(anyDeferredAction)
                    case .multiple(let actionArray):
                        actionArray.forEach({
                            switch $0 {
                            case .performDeferredAction(let anyDeferredAction):
                                self.runDeferredAction(anyDeferredAction)
                            case .performAction(let action):
                                self.dispatch(action)
                            case .performRoute(let route):
                                self.route(route)
                            default:
                                break
                            }
                        })
                    }
                })
                .store(in: &middlewareCancellables)
        }
    }
    
    /// Wrapper for your navigation concepts you can perform route action in simple Coordinator class
    /// - Parameter transition: AnyRoute
    public func route(_ transition: Router) {
        coordinator.perform(transition)
    }
    
    /// Deferred action runner
    /// - Parameter action: Erase deferred action and execute them
    private func runDeferredAction(_ action: AnyDeferredAction<Action>) {
        guard let _action = action.observe() else { return }
        _action
            .sink { [weak self] action in
                guard let self = self else { return }
                self.dispatch(action)
            }.store(in: &middlewareCancellables)
    }
    
}
