//
//  HttpServer.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//
import Foundation
import Network

enum HttpError: Error {
    case invalidData
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

struct HttpResponse {
    var httpVersion = HttpVersion.v1_1
    var status: Int = 200
    var headers: [String: String] = [:]
    var body: String?
    
    func toData() -> Data {
        var lines = ["\(httpVersion) \(status) \(statusText)"]
        
        // Add content length
        lines.append("Content-Length: \(body?.utf8.count ?? 0)")
        
        // Add custom headers
        for (key, value) in headers {
            lines.append("\(key): \(value)")
        }
        
        // Empty line + body
        lines.append("")
        lines.append(body ?? "")
        
        return lines.joined(separator: "\r\n").data(using: .utf8)!
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

protocol HttpDelegate {
    func httpServer(_ server: HttpServer, didReceiveRequest request: HttpRequest) -> HttpResponse
    func httpServer(_ server: HttpServer, didConnect sseClient: Response) -> Void
    func httpServer(_ server: HttpServer, didDisconnect sseClient: Response) -> Void
}

class HttpServer {
    private var listener: NWListener?
    private var delegate: HttpDelegate
    
    private(set) var sseClients: [Response] = []
    private let queue: DispatchQueue = DispatchQueue(label: "com.pigeon.httpserver", qos: .userInteractive)

    let port: NWEndpoint.Port
    var url: URL?
    
    init(port: NWEndpoint.Port = 8787, delegate: HttpDelegate) {
        self.delegate = delegate
        self.port = port
    }
    
    func handleSSE(connection: NWConnection) {
        let client = Response(connection: connection)
        self.sseClients.append(client)
        DispatchQueue.main.async {
            self.delegate.httpServer(self, didConnect: client)
        }
        // Monitor for disconnect
        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state {
                self?.removeClient(client)
            } else if case .failed = state {
                self?.removeClient(client)
            }
        }
    }
    
    func connect() throws {
        self.listener = try NWListener(using: .tcp, on: port)
        self.listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: self!.queue)  // ← background queue
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
                guard let self, let request = try? HttpRequest(data) else { return }
                
                // handle server side events here:
                if request.method == "GET" && request.headers["Accept"] == "text/event-stream" {
                    self.handleSSE(connection: connection)
                    return
                }
                
                // otherwise handle as a normal response:
                DispatchQueue.main.async {
                    let response = self.delegate.httpServer(self, didReceiveRequest: request)
                    connection.send(content: response.toData(), completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
            }
        }
        self.listener?.start(queue: queue)
        self.url = URL(string: "http://localhost:\(port)")!
    }
    
    func disconnect() {
        self.listener?.cancel()
        self.listener = nil
    }
    
    // MARK: - SSE Methods
    
    private func removeClient(_ client: Response) {
        sseClients.removeAll { $0.id == client.id }
        DispatchQueue.main.async {
            self.delegate.httpServer(self, didDisconnect: client)
        }
    }
    
    func broadcast(event: String? = nil, data: String, id: String? = nil) {
        for client in sseClients {
            client.sendEvent(data, event: event, id: id)
        }
    }
}
