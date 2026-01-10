//
//  PigeonApp.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import SwiftUI
internal import Combine
import Network

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


extension URL {
    var isLocalHost: Bool {
        guard let host = self.host() else { return false }
        guard !host.isEmpty else { return true }
        print("[URL] isLocalHost: \(host)")
        return host.contains("localhost")
    }
}


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
    
    func httpServer(_ server: HttpServer, didReceiveRequest request: HttpRequest) -> HttpResponse {
        switch request.method {
        case "OPTIONS":
            return HttpResponse(status: 200).withCORS()
        case "POST":
            self.handleIncomingRequest(request)
            return HttpResponse(status: 200)
        case "GET":
            return HttpResponse(status: 200)
        default:
            return HttpResponse(status: 404)
        }
    }
    
    func handleIncomingRequest(_ request: HttpRequest) {
        guard let body = request.body, !body.isEmpty else { return }
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
        print("Stream error: \(error)")
        self.isConnected = false
    }
}
