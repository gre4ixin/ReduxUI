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

protocol ReducerInterface {
    associatedtype S: AnyState
    associatedtype A: AnyAction
    associatedtype R: RouteType
    
    func reduce(_ state: inout S, action: A, performRoute: @escaping ((_ route: R) -> Void))
}


public final class Store<S: AnyState, A: AnyAction, R: RouteType>: ObservableObject {
    
    @Published public private(set) var state: S
    
    public typealias Reducer = (_ state: inout S, _ action: A, _ performRoute: @escaping PerformRoute) -> Void
    public typealias PerformRoute = (_ route: R) -> Void
    
    private let reduce: Reducer
    private var performRoute: PerformRoute!
    private(set) var middlewares: [AnyMiddleware<S, A, R>] = []
    private var middlewareCancellables = CombineBag()
    private var coordinator: AnyCoordinator<R>
    private let queue = DispatchQueue(label: "redux.serial.queue")
    
    public init(initialState: S, coordinator: AnyCoordinator<R>, reducer: @escaping Reducer) {
        self.state = initialState
        self.reduce = reducer
        self.coordinator = coordinator
        self.performRoute = { [weak self] route in
            guard let self = self else { return }
            self.route(route)
        }
    }
    
    public func add(_ middleware: AnyMiddleware<S, A, R>) {
        middlewares.append(middleware)
    }
    
    public func dispatch(_ action: A) {
        reduce(&state, action, performRoute)
        
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
    
    public func route(_ transition: R) {
        coordinator.perform(transition)
    }
    
    private func runDeferredAction(_ action: AnyDeferredAction<A>) {
        guard let _action = action.observe() else { return }
        _action
            .sink { action in
                self.dispatch(action)
            }.store(in: &middlewareCancellables)
    }
    
}
