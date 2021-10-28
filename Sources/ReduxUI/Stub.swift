//
//  File.swift
//  
//
//  Created by p.grechikhin on 29.10.2021.
//

import Foundation

public struct _DefaultStubState: AnyState {}
public struct _DefaultStubAction: AnyAction {}

struct Stuber {
    static func make() -> Store<_DefaultStubState, _DefaultStubAction> {
        let store = Store<_DefaultStubState, _DefaultStubAction>(initialState: _DefaultStubState()) { state, _ in return state}
        return store
    }
}
