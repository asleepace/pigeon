//
//  HttpResponse.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import Foundation

struct HttpResponse {
    var httpVersion = HttpVersion.v1_1
    var status: Int = 200
    var headers: [String: String] = [:]
    var body: String?

    func toData() -> Data {
        var lines = ["\(httpVersion.rawValue) \(status) \(statusText)"]

        // Add content length
        lines.append("Content-Length: \(body?.utf8.count ?? 0)")

        // Add custom headers
        for (key, value) in headers {
            lines.append("\(key): \(value)")
        }

        // Empty line + body
        lines.append("")
        lines.append(body ?? "")

        return lines.joined(separator: "\r\n").data(using: .utf8) ?? Data()
    }

    private var statusText: String {
        switch status {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "OK"
        }
    }

    // MARK: - Factory Methods

    static func ok(_ body: String? = nil) -> HttpResponse {
        HttpResponse(status: 200, body: body)
    }

    static func json(_ body: String) -> HttpResponse {
        HttpResponse(
            status: 200,
            headers: ["Content-Type": "application/json"],
            body: body
        )
    }

    static func notFound(_ message: String = "Not Found") -> HttpResponse {
        HttpResponse(status: 404, body: message)
    }

    static func error(_ message: String = "Internal Server Error") -> HttpResponse {
        HttpResponse(status: 500, body: message)
    }

    static func noContent() -> HttpResponse {
        HttpResponse(status: 204)
    }

    // MARK: - Modifiers

    func withCORS() -> HttpResponse {
        var copy = self
        copy.headers["Access-Control-Allow-Origin"] = "*"
        copy.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        copy.headers["Access-Control-Allow-Headers"] = "Content-Type, X-Event-Type"
        return copy
    }

    func withHeader(_ key: String, _ value: String) -> HttpResponse {
        var copy = self
        copy.headers[key] = value
        return copy
    }
}
