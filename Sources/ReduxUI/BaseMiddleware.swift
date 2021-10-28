//
//  File.swift
//  
//
//  Created by p.grechikhin on 29.10.2021.
//

import Combine
import Foundation

@available(iOS 13.0, *)
open class Middleware<S: AnyState, A: AnyAction> {
    public init() { }
    open func execute(_ state: S, action: A) -> AnyPublisher<A, Never>? { return nil }
}
