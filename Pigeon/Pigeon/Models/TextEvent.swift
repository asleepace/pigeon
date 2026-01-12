//
//  TextEvent.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import Foundation

struct TextEvent: Identifiable {
    let id = UUID()
    let eventId: String
    let type: String?
    let data: String?
    let timestamp: Date

    init(_ chunk: String) {
        var eventId: String = ""
        var type: String = "message"
        var data: String?

        chunk.split(separator: "\n").forEach { line in
            if line.starts(with: "id: ") {
                eventId = String(line.dropFirst(4))
            } else if line.starts(with: "event: ") {
                type = String(line.dropFirst(7))
            } else if line.starts(with: "data: ") {
                data = String(line.dropFirst(6))
            }
        }

        // System events are JSON objects {}
        if data?.hasPrefix("{") == true && data?.hasSuffix("}") == true {
            type = "system"
        }

        self.type = type
        self.data = data
        self.eventId = eventId
        self.timestamp = Date()
    }

    func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = self.data?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
