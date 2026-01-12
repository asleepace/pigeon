//
//  StreamConnection.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import Foundation

struct StreamConnection: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var url: String

    init(id: UUID = UUID(), name: String, url: String) {
        self.id = id
        self.name = name
        self.url = url
    }
}
