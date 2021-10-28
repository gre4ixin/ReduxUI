//
//  File.swift
//  
//
//  Created by p.grechikhin on 29.10.2021.
//

import Combine
import SwiftUI
import Foundation

@available(iOS 13.0, *)
public final class Store<S: AnyState, A: AnyAction>: ObservableObject {
    @Published public private(set) var state: S
    
    public typealias Reducer = (_ state: S, _ action: A) -> S
    
    private let reduce: Reducer
    public private(set) var middlewares: [Middleware<S, A>] = []
    private var middlewareCancellables: Set<AnyCancellable> = []
    
    private let queue =  DispatchQueue(label: "redux.serial.queue")
    
    public init(initialState: S, reducer: @escaping Reducer) {
        self.state = initialState
        self.reduce = reducer
    }
    
    public func add(_ middleware: Middleware<S, A>) {
        middlewares.append(middleware)
    }
    
    @available(iOS 13.0, *)
    public func dispatch(_ action: A) {
        state = reduce(state, action)
        
        for mw in middlewares {
            guard let future = mw.execute(state, action: action) else { return }
            
            future
                .subscribe(on: queue)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: dispatch)
                .store(in: &middlewareCancellables)
        }
        
    }
    
}
