import XCTest
import Combine
@testable import ReduxUI

// MARK: - Fixtures

private struct TestState: AnyState {
    var counter = 0
    var loaded = false
    var message = ""
}

private enum TestAction: AnyAction {
    case increment
    case decrement
    case set(Int)
    case navigate
    case load
    case loaded(String)
    case triggerMultiple
    case triggerDeferred
    case triggerAsync
}

private enum TestRoute: AnyRoute, Equatable {
    case detail
}

private final class TestCoordinator: Coordinator {
    private(set) var performed: [TestRoute] = []
    func perform(_ route: TestRoute) {
        performed.append(route)
    }
}

private final class TestReducer: Reducer {
    typealias State = TestState
    typealias Action = TestAction
    typealias Router = TestRoute

    func reduce(_ state: inout TestState, action: TestAction, performRoute: @escaping (TestRoute) -> Void) {
        switch action {
        case .increment:
            state.counter += 1
        case .decrement:
            state.counter -= 1
        case .set(let value):
            state.counter = value
        case .navigate:
            performRoute(.detail)
        case .load:
            state.loaded = false
        case .loaded(let message):
            state.loaded = true
            state.message = message
        case .triggerMultiple, .triggerDeferred, .triggerAsync:
            break
        }
    }
}

private final class LoadMiddleware: Middleware {
    typealias State = TestState
    typealias Action = TestAction
    typealias Router = TestRoute

    func execute(_ state: TestState, action: TestAction) -> AnyPublisher<MiddlewareAction<TestAction, TestRoute>, Never>? {
        switch action {
        case .load:
            let result: MiddlewareAction<TestAction, TestRoute> = .performAction(.loaded("loaded"))
            return Just(result).eraseToAnyPublisher()
        default:
            return nil
        }
    }
}

private final class NilMiddleware: Middleware {
    typealias State = TestState
    typealias Action = TestAction
    typealias Router = TestRoute

    func execute(_ state: TestState, action: TestAction) -> AnyPublisher<MiddlewareAction<TestAction, TestRoute>, Never>? {
        return nil
    }
}

private final class MultipleMiddleware: Middleware {
    typealias State = TestState
    typealias Action = TestAction
    typealias Router = TestRoute

    func execute(_ state: TestState, action: TestAction) -> AnyPublisher<MiddlewareAction<TestAction, TestRoute>, Never>? {
        switch action {
        case .triggerMultiple:
            let result: MiddlewareAction<TestAction, TestRoute> = .multiple([
                .performAction(.increment),
                .performAction(.increment),
                .multiple([.performAction(.increment)])
            ])
            return Just(result).eraseToAnyPublisher()
        default:
            return nil
        }
    }
}

private final class AutoDeferredAction: DeferredAction {
    typealias Action = TestAction

    func observe() -> AnyPublisher<TestAction, Never>? {
        return Just(.increment).eraseToAnyPublisher()
    }
}

private final class DeferredMiddleware: Middleware {
    typealias State = TestState
    typealias Action = TestAction
    typealias Router = TestRoute

    func execute(_ state: TestState, action: TestAction) -> AnyPublisher<MiddlewareAction<TestAction, TestRoute>, Never>? {
        switch action {
        case .triggerDeferred:
            let result: MiddlewareAction<TestAction, TestRoute> = .performDeferredAction(AutoDeferredAction().eraseToAnyDeferredAction())
            return Just(result).eraseToAnyPublisher()
        default:
            return nil
        }
    }
}

#if swift(>=5.5)
private final class AsyncSetMiddleware: AsyncMiddleware {
    typealias State = TestState
    typealias Action = TestAction
    typealias Router = TestRoute

    func execute(_ state: TestState, action: TestAction) async -> MiddlewareAction<TestAction, TestRoute>? {
        switch action {
        case .triggerAsync:
            return .performAction(.set(42))
        default:
            return nil
        }
    }
}
#endif

// MARK: - Tests

final class ReduxUITests: XCTestCase {

    private func makeStore(coordinator: TestCoordinator = TestCoordinator()) -> Store<TestState, TestAction, TestRoute> {
        Store(
            initialState: TestState(),
            coordinator: coordinator.eraseToAnyCoordinator(),
            reducer: TestReducer().eraseToAnyReducer()
        )
    }

    private func awaitState(
        in store: Store<TestState, TestAction, TestRoute>,
        timeout: TimeInterval = 2,
        until predicate: @escaping (TestState) -> Bool
    ) {
        let exp = expectation(description: "state predicate")
        exp.assertForOverFulfill = false
        let cancellable = store.$state.sink { state in
            if predicate(state) { exp.fulfill() }
        }
        wait(for: [exp], timeout: timeout)
        cancellable.cancel()
    }

    func testReducerIncrement() {
        let store = makeStore()
        store.dispatch(.increment)
        store.dispatch(.increment)
        XCTAssertEqual(store.state.counter, 2)
    }

    func testReducerDecrement() {
        let store = makeStore()
        store.dispatch(.set(5))
        store.dispatch(.decrement)
        XCTAssertEqual(store.state.counter, 4)
    }

    func testNavigateActionPerformsRoute() {
        let coordinator = TestCoordinator()
        let store = makeStore(coordinator: coordinator)
        store.dispatch(.navigate)
        XCTAssertEqual(coordinator.performed, [.detail])
    }

    func testMiddlewarePerformsAction() {
        let store = makeStore()
        store.add(LoadMiddleware().eraseToAnyMiddleware())
        store.dispatch(.load)
        awaitState(in: store) { $0.loaded && $0.message == "loaded" }
    }

    /// Regression test for the middleware loop bug: a middleware returning `nil`
    /// must not stop later middlewares from receiving the action.
    func testAllMiddlewaresRunWhenEarlierReturnsNil() {
        let store = makeStore()
        store.add(NilMiddleware().eraseToAnyMiddleware())
        store.add(LoadMiddleware().eraseToAnyMiddleware())
        store.dispatch(.load)
        awaitState(in: store) { $0.message == "loaded" }
    }

    func testMultipleMiddlewareActionsAreAllApplied() {
        let store = makeStore()
        store.add(MultipleMiddleware().eraseToAnyMiddleware())
        store.dispatch(.triggerMultiple)
        awaitState(in: store) { $0.counter == 3 }
    }

    func testDeferredActionIsObserved() {
        let store = makeStore()
        store.add(DeferredMiddleware().eraseToAnyMiddleware())
        store.dispatch(.triggerDeferred)
        awaitState(in: store) { $0.counter == 1 }
    }

    func testDispatchFromBackgroundThreadUpdatesState() {
        let store = makeStore()
        DispatchQueue.global().async {
            store.dispatch(.set(99))
        }
        awaitState(in: store) { $0.counter == 99 }
    }

    #if swift(>=5.5)
    func testAsyncMiddlewarePerformsAction() {
        let store = makeStore()
        store.add(AsyncSetMiddleware().eraseToAnyMiddleware())
        store.dispatch(.triggerAsync)
        awaitState(in: store) { $0.counter == 42 }
    }
    #endif
}
