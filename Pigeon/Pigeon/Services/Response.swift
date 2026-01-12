//
//  Response.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/11/26.
//

import Foundation
import Network

class Response {
    let id = UUID()
    let connection: NWConnection
    var headers: HttpHeaders = .init([
        "Cache-Control": "no-cache",
        "Access-Control-Allow-Origin": "*"
    ])

    var body: String?
    private(set) var isReady = false
    private(set) var isClosed = false
    
    var isTextEventStream: Bool {
        headers.get("Content-Type") == "text/event-stream"
    }
    
    init(connection: NWConnection, headers: HttpHeaders = .init(), body: String? = nil) {
        self.connection = connection
        self.headers = headers
        self.body = body
        
        connection.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            switch newState {
            case .ready:
                self.isReady = true
            case .cancelled, .failed:
                self.isReady = false
                self.isClosed = true
            default:
                break
            }
        }
    }

    func toData() -> Data {
        let hdrs = headers.toString()
        guard let body = self.body else { return (hdrs + "\r\n").data(using: .utf8) ?? Data() }
        return [hdrs, "", body].joined(separator: "\r\n").data(using: .utf8) ?? Data()
    }
    
    // MARK: - SSE Methods
    
    func startEventStream() {
        guard !isClosed else { return }
        headers.set("Content-Type", "text/event-stream")
        headers.set("Connection", "keep-alive")
        guard let headerData = (headers.toString() + "\r\n").data(using: .utf8) else { return }
        connection.send(content: headerData, completion: .contentProcessed { _ in })
    }
    
    func sendEvent(_ data: String, event: String? = nil, id: String? = nil) {
        guard !isClosed else { return }
        var message = ""
        if let id { message += "id: \(id)\n" }
        if let event { message += "event: \(event)\n" }
        message += "data: \(data)\n\n"
        
        // append to body so it can be re-sent later.
        if body != nil {
            self.body! += message
        } else {
            self.body = message
        }
        
        connection.send(content: message.data(using: .utf8), completion: .contentProcessed { _ in })
    }
    
    // MARK: - HTTP Methods
    
    func send(_ body: String? = nil, status: Int = 200) {
        guard !isClosed else { return }
        self.body = body
        self.headers.status = status
        
        connection.send(content: toData(), completion: .contentProcessed { [weak self] _ in
            guard let self, !self.isTextEventStream else { return }
            self.close()
        })
    }
    
    func json(_ body: String, status: Int = 200) {
        headers.set("Content-Type", "application/json")
        send(body, status: status)
    }
    
    func notFound(_ message: String = "Not Found") {
        send(message, status: 404)
    }
    
    func noContent() {
        send(nil, status: 204)
    }
    
    func close() {
        guard !isClosed else { return }
        isClosed = true
        connection.cancel()
    }
}
