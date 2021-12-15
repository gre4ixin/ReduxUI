//
//  NetworkWrapper.swift
//  ReduxUIExampleApp
//
//  Created by p.grechikhin on 15.12.2021.
//

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
