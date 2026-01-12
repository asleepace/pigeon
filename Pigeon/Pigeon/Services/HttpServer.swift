//
//  HttpServer.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import Foundation
import Network

protocol HttpDelegate {
    func httpServer(_ server: HttpServer, didReceiveRequest request: HttpRequest) -> HttpResponse
    func httpServer(_ server: HttpServer, didConnect sseClient: Response)
    func httpServer(_ server: HttpServer, didDisconnect sseClient: Response)
}

class HttpServer {
    private var listener: NWListener?
    private var delegate: HttpDelegate

    private(set) var sseClients: [Response] = []
    private let queue = DispatchQueue(label: "com.pigeon.httpserver", qos: .userInteractive)

    let port: NWEndpoint.Port
    var url: URL?

    init(port: NWEndpoint.Port = 8787, delegate: HttpDelegate) {
        self.delegate = delegate
        self.port = port
    }

    // MARK: - Connection Management

    func connect() throws {
        listener = try NWListener(using: .tcp, on: port)
        listener?.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            connection.start(queue: self.queue)
            self.receiveRequest(connection: connection)
        }
        listener?.start(queue: queue)
        url = URL(string: "http://localhost:\(port)")
    }

    func disconnect() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Request Handling

    func receiveRequest(connection: NWConnection, accumulated: Data = Data()) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, _ in
            guard let self else { return }

            var buffer = accumulated
            if let data { buffer.append(data) }

            // Check if we have full request (headers + body)
            if let request = try? HttpRequest(buffer), self.hasCompleteBody(request, data: buffer) {
                // Handle SSE request
                if request.method == "GET" && request.headers["Accept"] == "text/event-stream" {
                    self.handleSSE(connection: connection)
                    return
                }

                // Handle regular request
                DispatchQueue.main.async {
                    let response = self.delegate.httpServer(self, didReceiveRequest: request)
                    self.queue.async {
                        connection.send(content: response.toData(), completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                    }
                }
            } else if !isComplete {
                // Keep reading
                self.receiveRequest(connection: connection, accumulated: buffer)
            }
        }
    }

    private func hasCompleteBody(_ request: HttpRequest, data: Data) -> Bool {
        guard let contentLength = request.headers["Content-Length"],
              let length = Int(contentLength) else {
            return true  // No content-length = no body expected
        }
        let bodyLength = request.body?.utf8.count ?? 0
        return bodyLength >= length
    }

    // MARK: - SSE Methods

    private func handleSSE(connection: NWConnection) {
        let client = Response(connection: connection)
        sseClients.append(client)
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
