//
//  StreamManager.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//
//  Coordinates text/event-stream connections from either remote hosts or the internal
//  local HTTP server. Other applications can send HTTP requests to localhost:8787
//  and have the body broadcasted to the relevant stream.
//

import Foundation
import Combine
import Network

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(String)
}

class StreamManager: ObservableObject, TextEventStreamDelegate, HttpDelegate {

    // MARK: - Published State

    @Published var url: URL?
    @Published var eventsByStream: [String: [TextEvent]] = [:]
    @Published var connectionState: ConnectionState = .disconnected
    @Published var connectionError: String?
    @Published var searchQuery: String = ""
    @Published var filterType: String? = nil

    var isConnected: Bool {
        connectionState == .connected
    }

    // MARK: - Private Properties

    private var stream: TextEventStream?
    private var httpServer: HttpServer?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 10
    private let baseReconnectDelay: TimeInterval = 1.0
    private var namedPipeReader: NamedPipeReader? = nil
    
    init() {
        do {
            self.namedPipeReader = try NamedPipeReader()
            try self.namedPipeReader?.start { pipeData in
                print("[StreamManager] pipeData: \(pipeData)")
            }
        } catch {
            print("[StreamManager] failed to initialize NamedPipeReader: \(error)")
        }
    }

    // MARK: - Event Access

    /// Get events for a specific stream URL
    func events(for streamUrl: String) -> [TextEvent] {
        var events = eventsByStream[streamUrl] ?? []

        // Apply search filter
        if !searchQuery.isEmpty {
            events = events.filter { event in
                event.data?.localizedCaseInsensitiveContains(searchQuery) ?? false
            }
        }

        // Apply type filter
        if let filterType = filterType {
            events = events.filter { $0.type == filterType }
        }

        return events
    }

    /// Clear events for a specific stream URL
    func clearEvents(for streamUrl: String) {
        eventsByStream[streamUrl] = []
    }

    // MARK: - Connection Management

    func connect(to url: URL) {
        // Cancel any pending reconnect
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempt = 0

        // Disconnect previous stream but preserve its events
        stream?.disconnect()
        httpServer?.disconnect()

        self.url = url
        self.connectionError = nil
        self.connectionState = .connecting

        // Initialize event array for this stream if needed
        let urlKey = url.absoluteString
        if eventsByStream[urlKey] == nil {
            eventsByStream[urlKey] = []
        }

        // Start local HTTP server for localhost URLs
        if url.isLocalHost {
            httpServer = HttpServer(port: 8787, delegate: self)
            do {
                try httpServer?.connect()
            } catch {
                connectionError = "Failed to start local server: \(error.localizedDescription)"
            }
        }

        stream = TextEventStream(url, delegate: self)
        stream?.connect()
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempt = 0
        stream?.disconnect()
        httpServer?.disconnect()
        connectionState = .disconnected
    }

    // MARK: - Auto-Reconnect

    private func scheduleReconnect() {
        guard let url = self.url else { return }
        guard reconnectAttempt < maxReconnectAttempts else {
            connectionState = .failed("Max reconnect attempts reached")
            return
        }

        reconnectAttempt += 1
        connectionState = .reconnecting(attempt: reconnectAttempt)

        // Exponential backoff: 1s, 2s, 4s, 8s... max 30s
        let delay = min(baseReconnectDelay * pow(2.0, Double(reconnectAttempt - 1)), 30.0)

        reconnectTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            self.stream = TextEventStream(url, delegate: self)
            self.stream?.connect()
        }
    }

    // MARK: - HttpDelegate

    func httpServer(_ server: HttpServer, didConnect sseClient: Response) {
        sseClient.startEventStream()
        sseClient.sendEvent("{\"status\": \"connected\"}")
    }

    func httpServer(_ server: HttpServer, didDisconnect sseClient: Response) {
        // Client disconnected
    }

    func httpServer(_ server: HttpServer, didReceiveRequest request: HttpRequest) -> HttpResponse {
        switch request.method {
        case "OPTIONS":
            return HttpResponse(status: 200).withCORS()
        case "POST":
            handleIncomingRequest(request)
            return HttpResponse(status: 200).withCORS()
        default:
            return HttpResponse(status: 404)
        }
    }

    private func handleIncomingRequest(_ request: HttpRequest) {
        guard let body = request.body, !body.isEmpty else { return }
        guard let urlKey = url?.absoluteString else { return }
        let textEvent = TextEvent("data: \(body)")
        eventsByStream[urlKey, default: []].append(textEvent)
    }

    // MARK: - TextEventStreamDelegate

    func textEventStreamDidReceive(textEvent: TextEvent) {
        guard let urlKey = url?.absoluteString else { return }
        eventsByStream[urlKey, default: []].append(textEvent)
        connectionState = .connected
        reconnectAttempt = 0
    }

    func textEventStreamDidError(error: Error) {
        // Don't treat cancellation as an error requiring reconnect
        if (error as NSError).code == NSURLErrorCancelled {
            connectionState = .disconnected
            return
        }

        connectionError = error.localizedDescription

        // Attempt to reconnect
        if reconnectAttempt < maxReconnectAttempts {
            scheduleReconnect()
        } else {
            connectionState = .failed(error.localizedDescription)
        }
    }
}
