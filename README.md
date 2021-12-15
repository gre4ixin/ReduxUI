# Simple Architecture like Redux

##### Very simple example of usage ReduxUI
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
    typealias A = AppAction

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

##### That was very simple example, in real life you have to use network request, action in app state changes and many other features. In these cases you can use `Middleware`.

##### `Middlewares` calls after reducer function and return 
```swift
 AnyPublisher<MiddlewareAction, Never>
```