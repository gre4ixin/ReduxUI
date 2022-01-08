![logo](./logo.png)

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-iOS-orange.svg">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.5-orange.svg">
  <img alt="License" src="https://img.shields.io/badge/LICENSE-MIT-blue.svg">
  <img alt="Platform Version" src="https://img.shields.io/badge/iOS-13-green.svg">
</p>


# Simple Architecture like Redux

## Installation
### SPM
```swift
dependencies: [
    .package(url: "https://github.com/gre4ixin/ReduxUI.git", .upToNextMinor(from: "1.0.0"))
]
```

## Usage 
```swift
import ReduxUI

class SomeCoordinator: Coordinator {
    func perform(_ route: SomeRoute) { }
}

enum SomeRoute: RouteType {

}

enum AppAction: AnyAction {
    case increase
    case decrease
}

struct AppState: AnyState {
    var counter: Int = 0
}

class AppReducer: Reducer {
    typealias Action = AppAction

    func reduce(_ state: inout AppState, action: AppAction, performRoute: @escaping ((_ route: SomeRoute) -> Void)) {
        switch action {
        case .increase:
            state.counter += 1
        case .decrease:
            state.counter -= 1
        }
    }
}

class ContentView: View {
    @EnvironmentObject var store: Store<AppState, AppAction, SomeRouter>

    var body: some View {
        VSTack {
            Text(store.state.counter)

            Button {
                store.dispatch(.increase)
            } label: {
                Text("increment")
            }

            Button {
                store.dispatch(.decrease)
            } label: {
                Text("decrement")
            }
        }
    }
}

class AppModuleAssembly {
    func build() -> some View {
        let reducer = AppReducer().eraseToAnyReducer()
        let coordinator = SomeCoordinator().eraseToAnyCoordinator()
        let store = Store(initialState: AppState(), coordinator: coordinator, reducer: reducer)
        let view = ContentView().environmentObject(store)
        return view
    }
}

```

That was very simple example, in real life you have to use network request, action in app state changes and many other features. In these cases you can use `Middleware`.

##### `Middlewares` calls after reducer function and return 
```swift
 AnyPublisher<MiddlewareAction, Never>
```

##### For example create simple project who fetch users from `https://jsonplaceholder.typicode.com/users`.

Create DTO (Decode to object) model
```swift
struct UserDTO: Decodable, Equatable, Identifiable {
    let id: Int
    let name: String
    let username: String
    let phone: String
}
```
`Equatable` protocol for our state, `Identifiable` for `ForEach` generate view in SwiftUI View.

##### Simple network request without error checking
```swift
import Foundation
import Combine

protocol NetworkWrapperInterface {
    func request<D: Decodable>(path: URL, decode: D.Type) -> AnyPublisher<D, NetworkError>
}

struct NetworkError: Error {
    let response: URLResponse?
    let error: Error?
}

class NetworkWrapper: NetworkWrapperInterface {
    
    func request<D: Decodable>(path: URL, decode: D.Type) -> AnyPublisher<D, NetworkError> {
        return Deferred {
            Future<D, NetworkError> { promise in
                let request = URLRequest(url: path)
                URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                    guard let _ = self else { return }
                    if let _error = error {
                        promise(.failure(NetworkError(response: response, error: _error)))
                    }
                    
                    guard let unwrapData = data, let json = try? JSONDecoder().decode(decode, from: unwrapData) else {
                        promise(.failure(NetworkError(response: response, error: error)))
                        return
                    }
                    
                    promise(.success(json))
                    
                }.resume()
            }
        }.eraseToAnyPublisher()
    }
    
}
```

##### Make `State`, `Action` and `Reducer`

```swift
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
    typealias Action = AppAction
    
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
```

##### Middleware for make network request and return `users DTO`.

```swift
class AppMiddleware: Middleware {
    typealias State = AppState
    typealias Action = AppAction
    typealias Router = RouteWrapperAction
    
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
```

`Content View`
```swift
@EnvironmentObject var store: Store<AppState, AppAction, RouteWrapperAction>
    
var body: some View {
    VStack {
        ScrollView {
            ForEach(store.state.users) { user in
                HStack {
                    VStack {
                        Text(user.name)
                            .padding(.leading, 16)
                        Text(user.phone)
                            .padding(.leading, 16)
                    }
                    Spacer()
                }
                Divider()
            }
        }
        Spacer()
        if store.state.isLoading {
            Text("Loading")
        }
        
        if !store.state.errorMessage.isEmpty {
            Text(LocalizedStringKey(store.state.errorMessage))
        }
        
        Button {
            store.dispatch(.fetch)
        } label: {
            Text("fetch users")
        }
    }
}
```

When reducer ended his job with action, our store check all added middlewares for some `Publishers` for curent `Action`, if Publisher not nil, `Store` runing that Publisher.

You can return action for reducer and change some data, return action for routing, return `.multiple` actions.

```swift
case multiple([MiddlewareAction<A, R>])
```

#### You can return `Deferred Action`.

```swift
public protocol DeferredAction {
    associatedtype Action: AnyAction
    func observe() -> AnyPublisher<Action, Never>?
    
    func eraseToAnyDeferredAction() -> AnyDeferredAction<A>
}
```

If you want route to Authorization, when your Session Provider send event about dead you session, you can use it `action`. All you need that conform to protocol `DeferredAction` you `class/struct` and erase it to `AnyDeferredAction` with generic `Action`.
