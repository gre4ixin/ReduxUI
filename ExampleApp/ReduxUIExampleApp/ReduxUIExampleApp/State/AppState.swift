//
//  AppState.swift
//  ReduxUIExampleApp
//
//  Created by p.grechikhin on 15.12.2021.
//

import Foundation
import ReduxUI
import Combine

enum RouteWrapperAction: AnyRoute { }

class CoordinatorWrapper: Coordinator {
    func perform(_ route: RouteWrapperAction) { }
}

enum AppAction: AnyAction {
    case fetch
    case isLoading
    case loadingEnded
    case updateUsers([UserDTO])
    case error(message: String)
}

struct AppState: AnyState {
    var users: [UserDTO] = []
    var isLoading = false
    var errorMessage = ""
}

class AppReducer: Reducer {
    typealias A = AppAction
    
    func reduce(_ state: inout AppState, action: AppAction, performRoute: @escaping ((RouteWrapperAction) -> Void)) {
        switch action {
        case .fetch:
            state.isLoading = true
            state.errorMessage = ""
        case .isLoading:
            state.isLoading = true
        case .loadingEnded:
            state.isLoading = false
        case .updateUsers(let users):
            state.users = users
            state.isLoading = false
            state.errorMessage = ""
        case .error(let message):
            state.errorMessage = message
        }
    }
}

class AppMiddleware: Middleware {
    typealias S = AppState
    typealias A = AppAction
    typealias R = RouteWrapperAction
    
    let networkWrapper: NetworkWrapperInterface
    
    var cancelabels = CombineBag()
    
    init(networkWrapper: NetworkWrapperInterface) {
        self.networkWrapper = networkWrapper
    }
    
    func execute(_ state: AppState, action: AppAction) -> AnyPublisher<MiddlewareAction<AppAction, RouteWrapperAction>, Never>? {
        switch action {
        case .fetch:
            return Deferred {
                Future<MiddlewareAction<AppAction, RouteWrapperAction>, Never> { [weak self] promise in
                    guard let self = self else { return }
                    self.networkWrapper
                        .request(path: URL(string: "https://jsonplaceholder.typicode.com/users")!, decode: [UserDTO].self)
                        .sink { result in
                            switch result {
                            case .finished: break
                            case .failure(let error):
                                promise(.success(.performAction(.error(message: "Something went wrong!"))))
                            }
                        } receiveValue: { dto in
                            promise(.success(.performAction(.updateUsers(dto))))
                        }.store(in: &self.cancelabels)
                }
            }.eraseToAnyPublisher()
        default:
            return nil
        }
    }
}
