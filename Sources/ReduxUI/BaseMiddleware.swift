//
//  File.swift
//  
//
//  Created by p.grechikhin on 29.10.2021.
//

import Combine
import Foundation

@available(iOS 13.0, *)
public class Middleware<S: State, A: Action> {
    public func execute(_ state: S, action: A) -> AnyPublisher<A, Never>? { return nil }
}
