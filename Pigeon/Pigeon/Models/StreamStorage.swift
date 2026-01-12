//
//  StreamStorage.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//
//  Persists stream configurations using UserDefaults.
//

import Foundation

enum StreamStorage {
    private static let storageKey = "com.pigeon.streams"

    private static let defaultStreams: [StreamConnection] = [
        StreamConnection(name: "Localhost", url: "http://localhost:8787/"),
        StreamConnection(name: "Console Dump", url: "https://consoledump.io/api/sse?id=31b2fe")
    ]

    static func load() -> [StreamConnection] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let streams = try? JSONDecoder().decode([StreamConnection].self, from: data),
              !streams.isEmpty else {
            return defaultStreams
        }
        return streams
    }

    static func save(_ streams: [StreamConnection]) {
        guard let data = try? JSONEncoder().encode(streams) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
