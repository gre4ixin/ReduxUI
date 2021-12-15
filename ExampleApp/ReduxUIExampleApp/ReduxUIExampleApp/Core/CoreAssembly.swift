//
//  CoreAssembly.swift
//  ReduxUIExampleApp
//
//  Created by p.grechikhin on 15.12.2021.
//

import Foundation
import ReduxUI
import SwiftUI

class CoreAssembly {
    lazy var coordinator: AnyCoordinator<RouteWrapperAction> = CoordinatorWrapper().eraseToAnyCoordinator()
    lazy var networkWrapper: NetworkWrapperInterface = NetworkWrapper()
    
    
    func contentView() -> some View {
        let reducer = AppReducer().eraseToAnyReducer()
        let middleware = AppMiddleware(networkWrapper: networkWrapper).eraseToAnyMiddleware()
        let store = Store(initialState: AppState(), coordinator: coordinator, reducer: reducer)
        store.add(middleware)
        let view = ContentView()
            .environmentObject(store)
        return view
    }
    
}
