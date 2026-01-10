//
//  EventListView.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import SwiftUI

struct EventListView: View {
    let stream: StreamConnection
    @EnvironmentObject var streamManager: StreamManager
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(streamManager.events.enumerated()), id: \.offset) { index, event in
                        TextEventView(event: event)
                            .id(index)
                        Divider()
                    }
                }
            }
            .onChange(of: streamManager.events.count) { _, _ in
                if let last = streamManager.events.indices.last {
                    withAnimation {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(stream.name)
        .toolbar {
            ToolbarItemGroup {
                Circle()
                    .fill(streamManager.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Button {
                    streamManager.events.removeAll()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Clear events")
                
                Button {
                    if streamManager.isConnected {
                        streamManager.disconnect()
                    } else {
                        try? streamManager.connect(to: URL(string: stream.url)!)
                    }
                } label: {
                    Image(systemName: streamManager.isConnected ? "stop.fill" : "play.fill")
                }
                .help(streamManager.isConnected ? "Disconnect" : "Connect")
            }
        }
    }
}
