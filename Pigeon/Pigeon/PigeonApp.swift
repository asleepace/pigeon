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
    @Published var events: [TextEvent] = []
    @Published var isConnected: Bool = false
    
    private var stream: TextEventStream?
    private var httpServer: HttpServer?
    
    func connect(to url: URL) {
        self.url = url
        self.stream?.disconnect()
        self.events = []
        if url.isLocalHost {
            self.httpServer = HttpServer(port: 8787, delegate: self)
            try? self.httpServer?.connect()
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
        print("[app] SSEClient connected: \(sseClient)")
        sseClient.startEventStream()
        sseClient.sendEvent("{\"status\" : \"connected\"}")
    }
    
    func httpServer(_ server: HttpServer, didDisconnect sseClient: Response) {
        print("[app] SSEClient disconnected: \(sseClient)")
    }
    
    func httpServer(_ server: HttpServer, didReceiveRequest request: HttpRequest) -> HttpResponse {
        print("[app] didReceiveRequest: \(request.method) \(request.path) \(request.headers)")
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
        guard let body = request.body, !body.isEmpty else {
            print("[app] incoming request missing body...")
            return
        }
        let textEvent = TextEvent("data: \(body)")
        textEvent.debug()
        self.events.append(textEvent)
    }
    
    // MARK: - TextEventStreamDelegate
    
    func textEventStreamDidReceive(textEvent: TextEvent) {
        self.events.append(textEvent)
        self.isConnected = true
    }
    
    func textEventStreamDidError(error: Error) {
        print("[textEventStreamDidError] error: \(error.localizedDescription)")
        self.isConnected = false
    }
}
