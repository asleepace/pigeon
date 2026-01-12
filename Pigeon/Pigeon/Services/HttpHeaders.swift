//
//  HttpHeaders.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/11/26.
//

import Foundation

enum HttpVersion: String, RawRepresentable {
    case v1_0 = "HTTP/1.0"
    case v1_1 = "HTTP/1.1"
    case v2_0 = "HTTP/2.0"
}

struct HttpHeaders {
    var httpVersion: HttpVersion = .v1_1  // Use 1.1 for SSE compatibility
    var status: Int = 200 {
        didSet { statusText = Self.statusText(for: status) }
    }
    private(set) var statusText: String = "OK"
    private var headers: [String: String] = [:]
    
    init(_ headers: [String: String] = [:]) {
        self.headers = headers
    }
    
    // MARK: - Accessors
    
    func has(_ name: String) -> Bool {
        headers.keys.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }
    
    func get(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
    
    // MARK: - Mutators
    
    @discardableResult
    mutating func set(_ name: String, _ value: String) -> Self {
        headers[name] = value
        return self
    }
    
    @discardableResult
    mutating func delete(_ name: String) -> Self {
        headers.removeValue(forKey: name)
        return self
    }
    
    // MARK: - Serialization
    
    func toString() -> String {
        var lines = ["\(httpVersion) \(status) \(statusText)"]
        for (key, value) in headers {
            lines.append("\(key): \(value)")
        }
        lines.append("")  // Blank line before body
        return lines.joined(separator: "\r\n")
    }
    
    func toData() -> Data {
        toString().data(using: .utf8) ?? Data()
    }
    
    // MARK: - Status Text
    
    private static func statusText(for status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 304: return "Not Modified"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        default: return "OK"
        }
    }
}
