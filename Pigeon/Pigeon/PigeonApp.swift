//
//  PigeonApp.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import SwiftUI
internal import Combine

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


class StreamManager: ObservableObject, TextEventStreamDelegate {
    
    @Published var url: URL?
    @Published var events: [TextEvent] = []
    @Published var isConnected: Bool = false
    
    private var stream: TextEventStream?
    
    func connect(to url: URL) {
        self.url = url
        self.stream?.disconnect()
        self.events = []
        self.stream = TextEventStream(url, delegate: self)
        self.stream?.connect()
    }
    
    func disconnect() {
        self.stream?.disconnect()
        self.isConnected = false
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
