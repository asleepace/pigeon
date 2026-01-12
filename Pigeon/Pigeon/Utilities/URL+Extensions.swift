//
//  URL+Extensions.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import Foundation

extension URL {
    var isLocalHost: Bool {
        guard let host = self.host() else { return false }
        guard !host.isEmpty else { return true }
        return host.contains("localhost") || host.contains("127.0.0.1")
    }
}
