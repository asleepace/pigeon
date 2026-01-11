//
//  fetch.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/11/26.
//
//  Functional fetch methods for the application.
//

import Foundation

typealias HTTPHeaders = [String: String]

enum FetchError: Error {
    case invalidURL(String)
    case invalidResponse(Int)
    case noData
    case invalidJSON
}

enum Method: String, Equatable {
    case POST = "POST"
    case GET = "GET"
    case OPTIONS = "OPTIONS"
    case HEAD = "HEAD"
    case PUT = "PUT"
    case PATCH = "PATCH"
    case DELETE = "DELETE"
}

struct FetchResponse {
    let httpResponse: HTTPURLResponse
    let data: Data?
    
    var status: Int {
        httpResponse.statusCode
    }
    
    var isEmpty: Bool {
        data == nil || data?.isEmpty == true
    }
    
    init(_ response: (Data?, URLResponse?)) throws {
        guard let httpResponse = response.1 as? HTTPURLResponse else {
            throw FetchError.invalidResponse(500)
        }
        self.httpResponse = httpResponse
        self.data = response.0
    }
    
    func text() throws -> String {
        guard let data = data else { throw FetchError.noData }
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    func json<T: Decodable>() throws -> T {
        guard let data = data else { throw FetchError.noData }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func jsonObject() throws -> Any {
        guard let data = data else { throw FetchError.noData }
        return try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    }
    
    func debugPrint() {
        let href = httpResponse.url?.absoluteString ?? "<unknown>"
        var dataInfo = try? jsonObject()
        if dataInfo == nil {
            dataInfo = try? self.text()
        }
        print("\(status) @ \(href)\r\n\t\(dataInfo ?? "<no data>")")
        
    }
}

// MARK: Convenience Methods

@discardableResult func fetch(_ href: String, headers: HTTPHeaders = [
    "Content-Type": "application/json",
    "Accept": "application/json",
],) async throws -> FetchResponse {
    try await fetch(href, method: .GET, headers: headers)
}

@discardableResult func fetch(_ href: String, body: Data, headers: HTTPHeaders = [
    "Content-Type": "application/json",
    "Accept": "application/json",
]) async throws -> FetchResponse {
    try await fetch(href, method: .POST, body: body)
}

@discardableResult func fetch<T: Encodable>(_ href: String, body: T, headers: HTTPHeaders = [
    "Content-Type": "application/json",
    "Accept": "application/json",
]) async throws -> FetchResponse {
    try await fetch(href, method: .POST, body: body)
}

// MARK: Implementation

@discardableResult func fetch(
    _ href: String,
    method: Method,
    headers: [String: String] = [
        "Content-Type": "application/json",
        "Accept": "application/json",
    ],
    body: Data? = nil,
) async throws -> FetchResponse {
    guard let url = URL(string: href) else { throw FetchError.invalidURL(href) }
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
    }
    if let body = body {
        request.httpBody = body
    }
    let output = try await URLSession.shared.data(for: request)
    return try FetchResponse(output)

}

@discardableResult func fetch<T: Encodable>(
    _ href: String,
    method: Method,
    headers: HTTPHeaders = [
        "Content-Type": "application/json",
        "Accept": "application/json",
    ],
    body: T
) async throws -> FetchResponse {
    let data = try JSONEncoder().encode(body)
    return try await fetch(href, method: method, headers: headers, body: data)
}


func fetch<T: Encodable>(
    _ href: String,
    method: Method,
    headers: [String: String] = [
        "Content-Type": "application/json",
        "Accept": "application/json",
    ],
    body: T,
    _ completion: @escaping (Result<FetchResponse, any Error>) -> Void
) {
    Task {
        do {
            let response = try await fetch(href, method: method, headers: headers, body: body)
            completion(.success(response))
        } catch {
            completion(.failure(error))
        }
    }
}
