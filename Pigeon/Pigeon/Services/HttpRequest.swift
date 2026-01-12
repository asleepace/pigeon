//
//  HttpRequest.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import Foundation

enum HttpError: Error {
    case invalidData
    case invalidMethod
    case connectionFailed
}

struct HttpRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: String?

    init(_ data: Data?) throws {
        guard let data, let raw = String(data: data, encoding: .utf8) else {
            throw HttpError.invalidData
        }

        let parts = raw.components(separatedBy: "\r\n\r\n")
        let headerSection = parts[0]
        body = parts.count > 1 ? parts[1] : nil

        let lines = headerSection.split(separator: "\r\n")
        guard let requestLine = lines.first else { throw HttpError.invalidData }

        let requestParts = requestLine.split(separator: " ")
        method = String(requestParts[0])
        path = requestParts.count > 1 ? String(requestParts[1]) : "/"

        var hdrs: [String: String] = [:]
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1)
            if pair.count == 2 {
                hdrs[String(pair[0]).trimmingCharacters(in: .whitespaces)] =
                    String(pair[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        headers = hdrs
    }
}
