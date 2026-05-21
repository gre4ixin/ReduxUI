//
//  Store.swift
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

    private let reducer: AnyReducer<State, Action, Router>
    private(set) var middlewares: [AnyMiddleware<State, Action, Router>] = []
    private(set) var asyncMiddlewares: [AnyAsyncMiddleware<State, Action, Router>] = []
    /// One-shot middleware subscriptions, removed automatically on completion.
    private var middlewareCancellables: [UUID: AnyCancellable] = [:]
    /// Long-lived deferred-action subscriptions.
    private var deferredCancellables = CombineBag()
    private var coordinator: AnyCoordinator<Router>
    private let queue = DispatchQueue(label: "redux.serial.queue")

    /// Init store with initial state value if you have to use DI
    /// - Parameters:
    ///   - initialState: your State
    ///   - coordinator:
    ///   - reducer: AnyReducer
    public init(initialState: State, coordinator: AnyCoordinator<Router>, reducer: StoreReducer) {
        self.state = initialState
        self.coordinator = coordinator
        self.reducer = reducer

        reducer.handlingOutputAction { [weak self] outputAction in
            self?.dispatch(outputAction)
        }
    }

    public func add(_ middleware: AnyMiddleware<State, Action, Router>) {
        middlewares.append(middleware)
    }

    #if swift(>=5.5)

    public func add(_ asyncMiddleware: AnyAsyncMiddleware<State, Action, Router>) {
        asyncMiddlewares.append(asyncMiddleware)
    }

    #endif

    /// Calling dispatch with action for processing State.
    ///
    /// Safe to call from any thread: the reducer runs and `state` is mutated on
    /// the main thread, which keeps SwiftUI updates valid.
    /// - Parameter action: AnyAction
    public func dispatch(_ action: Action) {
        if Thread.isMainThread {
            performDispatch(action)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.performDispatch(action)
            }
        }
    }

    /// Wrapper for your navigation concepts you can perform route action in simple Coordinator class
    /// - Parameter transition: AnyRoute
    public func route(_ transition: Router) {
        coordinator.perform(transition)
    }

    private func performDispatch(_ action: Action) {
        reducer.reduce(&state, action: action, performRoute: { [weak self] route in
            self?.route(route)
        })

        /// Check if any middlewares can perform current action
        performAnyMiddlewares(for: action)
        #if swift(>=5.5)
        performAsyncMiddlewares(for: action)
        #endif
    }

    /// Single place that interprets a `MiddlewareAction`, used by both sync and async middlewares.
    private func handle(_ middlewareAction: MiddlewareAction<Action, Router>) {
        switch middlewareAction {
        case .none:
            break
        case .performAction(let action):
            dispatch(action)
        case .performRoute(let route):
            self.route(route)
        case .performDeferredAction(let deferredAction):
            runDeferredAction(deferredAction)
        case .multiple(let actions):
            actions.forEach { handle($0) }
        }
    }

    /// Deferred action runner
    /// - Parameter action: Erase deferred action and execute them
    private func runDeferredAction(_ action: AnyDeferredAction<Action>) {
        guard let publisher = action.observe() else { return }
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] action in
                self?.dispatch(action)
            }
            .store(in: &deferredCancellables)
    }

    private func performAnyMiddlewares(for action: Action) {
        /// Check if any middlewares can perform current action
        for middleware in middlewares {
            guard let future = middleware.execute(state, action: action) else { continue }

            let id = UUID()
            let cancellable = future
                .subscribe(on: queue)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.middlewareCancellables[id] = nil
                }, receiveValue: { [weak self] middlewareAction in
                    self?.handle(middlewareAction)
                })
            middlewareCancellables[id] = cancellable
        }
    }

    #if swift(>=5.5)

    private func performAsyncMiddlewares(for action: Action) {
        let currentState = state
        for asyncMiddleware in asyncMiddlewares {
            Task { [weak self] in
                guard let middlewareAction = await asyncMiddleware.execute(currentState, action: action) else { return }
                await MainActor.run {
                    self?.handle(middlewareAction)
                }
            }
        }
    }

    #endif

}
