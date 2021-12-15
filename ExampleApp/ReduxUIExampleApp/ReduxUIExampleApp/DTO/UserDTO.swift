//
//  UserDTO.swift
//  ReduxUIExampleApp
//
//  Created by p.grechikhin on 15.12.2021.
//

import Foundation

struct UserDTO: Decodable, Equatable, Identifiable {
    let id: Int
    let name: String
    let username: String
    let phone: String
}
