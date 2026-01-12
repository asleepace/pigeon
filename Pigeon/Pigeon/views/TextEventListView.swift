//
//  TextEventListView.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import SwiftUI

struct CodeLine: View {
    var code: String
    var body: some View {
        HStack {
            Text(code)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct CodeBlock: View {
    var code: String
    
    var body: some View {
        HStack {
            Text(code)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .textSelection(.enabled)
            
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct TextEventListLoadingView: View {
    
    func sendTestEvent() async {
        do {
            _ = try await fetch(
                  streamUrl,
                  method: .POST,
                  headers: [
                    "Content-Type": "text/plain",
                  ],
                  body: "Hello, world!".data(using: .utf8)
            )
        } catch {
            // Test event failed to send
        }
    }
    
    var streamName: String
    var streamUrl: String
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4.0)
            ContentUnavailableView(
                streamName,
                systemImage: "antenna.radiowaves.left.and.right",
                description: Text("Waiting for incoming events, to get started make an http request to the following endpoint:")
            )
            CodeLine(code: "curl -d \"hello, world\" \(streamUrl)")
            Spacer(minLength: 4.0)
            Button("Send Event") {
                Task {
                    await sendTestEvent()
                }
            }
            .foregroundStyle(Color.white)
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 4))
        }
    }
}


struct TextEventListView: View {
    let stream: StreamConnection
    @EnvironmentObject var streamManager: StreamManager
    
    var messages: [TextEvent] {
        streamManager.events.filter { $0.type == "message" }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            if messages.isEmpty {
                TextEventListLoadingView(streamName: stream.name, streamUrl: stream.url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 44.0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, event in
                            TextEventView(event: event)
                                .id(index)
                            Divider()
                                .padding(.leading, 10)
                        }
                    }
                    .padding(.top, 1)
                }
                .onChange(of: streamManager.events.count) { _, _ in
                    if let last = streamManager.events.indices.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(stream.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarContent
            }
        }
    }
    
    private var toolbarContent: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(streamManager.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .padding(.horizontal, 8.0)
            
            Button {
                streamManager.events.removeAll()
            } label: {
                Image(systemName: "trash")
            }
            .help("Clear events")
            
            Button {
                if streamManager.isConnected {
                    streamManager.disconnect()
                } else if let url = URL(string: stream.url) {
                    streamManager.connect(to: url)
                }
            } label: {
                Image(systemName: streamManager.isConnected ? "pause.fill" : "play.fill")
            }
            .help(streamManager.isConnected ? "Disconnect" : "Connect")
        }
        .padding(.horizontal, 6.0)
    }
}
