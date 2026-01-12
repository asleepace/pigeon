//
//  PigeonApp.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//
import SwiftUI
import Combine
import Network

// MARK: Main App

@main
struct PigeonApp: App {
    @StateObject var streamManager = StreamManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(streamManager)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
    }
}

// MARK: Content View

struct ContentView: View {
    @EnvironmentObject var streamManager: StreamManager
    @State private var selectedStream: StreamConnection? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedStream: $selectedStream)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            if let stream = selectedStream {
                TextEventListView(stream: stream)
            } else {
                ContentUnavailableView(
                    "No Stream Selected",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Select or add a stream from the sidebar")
                )
            }
        }
        .frame(minWidth: 700, minHeight: 400)
    }
}


extension URL {
    var isLocalHost: Bool {
        guard let host = self.host() else { return false }
        guard !host.isEmpty else { return true }
        return host.contains("localhost") || host.contains("127.0.0.1")
    }
}

// MARK: Stream Manager
// Coordinate text/event-stream connections from either remote hosts or the internal
// local http server. Other applications should be able to send basic HTTP requests
// to a local url such as http://localhost:8787 and have the body broadcasted to
// the relevant stream.
class StreamManager: ObservableObject, TextEventStreamDelegate, HttpDelegate {

    @Published var url: URL?
    @Published var eventsByStream: [String: [TextEvent]] = [:]
    @Published var isConnected: Bool = false
    @Published var connectionError: String?

    private var stream: TextEventStream?
    private var httpServer: HttpServer?

    /// Get events for a specific stream URL
    func events(for streamUrl: String) -> [TextEvent] {
        eventsByStream[streamUrl] ?? []
    }

    /// Clear events for a specific stream URL
    func clearEvents(for streamUrl: String) {
        eventsByStream[streamUrl] = []
    }

    func connect(to url: URL) {
        // Disconnect previous stream but preserve its events
        self.stream?.disconnect()
        self.httpServer?.disconnect()

        self.url = url
        self.connectionError = nil
        self.isConnected = false

        // Initialize event array for this stream if needed
        let urlKey = url.absoluteString
        if eventsByStream[urlKey] == nil {
            eventsByStream[urlKey] = []
        }

        if url.isLocalHost {
            self.httpServer = HttpServer(port: 8787, delegate: self)
            do {
                try self.httpServer?.connect()
            } catch {
                self.connectionError = "Failed to start local server: \(error.localizedDescription)"
            }
        }
        self.stream = TextEventStream(url, delegate: self)
        self.stream?.connect()
    }

    func disconnect() {
        self.stream?.disconnect()
        self.httpServer?.disconnect()
        self.isConnected = false
    }
    
    // MARK: - HttpDelegate

    func httpServer(_ server: HttpServer, didConnect sseClient: Response) {
        sseClient.startEventStream()
        sseClient.sendEvent("{\"status\" : \"connected\"}")
    }

    func httpServer(_ server: HttpServer, didDisconnect sseClient: Response) {
        // Client disconnected
    }

    func httpServer(_ server: HttpServer, didReceiveRequest request: HttpRequest) -> HttpResponse {
        switch request.method {
        case "OPTIONS":
            return HttpResponse(status: 200).withCORS()
        case "POST":
            self.handleIncomingRequest(request)
            return HttpResponse(status: 200)
        default:
            return HttpResponse(status: 404)
        }
    }
    
    func handleIncomingRequest(_ request: HttpRequest) {
        guard let body = request.body, !body.isEmpty else { return }
        guard let urlKey = self.url?.absoluteString else { return }
        let textEvent = TextEvent("data: \(body)")
        eventsByStream[urlKey, default: []].append(textEvent)
    }

    // MARK: - TextEventStreamDelegate

    func textEventStreamDidReceive(textEvent: TextEvent) {
        guard let urlKey = self.url?.absoluteString else { return }
        eventsByStream[urlKey, default: []].append(textEvent)
        self.isConnected = true
    }
    
    func textEventStreamDidError(error: Error) {
        self.connectionError = error.localizedDescription
        self.isConnected = false
    }
}
