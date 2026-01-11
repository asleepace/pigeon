//
//  SideBarView.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//
// SidebarView.swift
import SwiftUI

struct StreamConnection: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var url: String
    var isConnected: Bool = false
}

struct SidebarView: View {
    @EnvironmentObject var streamManager: StreamManager
    @Binding var selectedStream: StreamConnection?
    
    @State private var streams: [StreamConnection] = [
        StreamConnection(name: "Console Dump", url: "https://consoledump.io/api/sse?id=31b2fe")
    ]
    @State private var isAddingStream = false
    @State private var newStreamName = ""
    @State private var newStreamURL = ""
    
    var body: some View {
        List(selection: $selectedStream) {
            streamsList
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $isAddingStream) {
            addStreamSheet
        }
        .onChange(of: selectedStream) { _, newStream in
            if let stream = newStream {
                streamManager.connect(to: URL(string: stream.url)!)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var streamsList: some View {
        Section("Streams") {
            ForEach(streams) { stream in
                StreamRow(stream: stream)
                    .tag(stream)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            streams.removeAll { $0.id == stream.id }
                        }
                    }
            }
        }
    }
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button {
                    isAddingStream = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            .padding(8)
        }
        .background(.ultraThinMaterial)
    }
    
    private var addStreamSheet: some View {
        AddStreamSheet(
            name: $newStreamName,
            url: $newStreamURL,
            onAdd: {
                let stream = StreamConnection(name: newStreamName, url: newStreamURL)
                streams.append(stream)
                newStreamName = ""
                newStreamURL = ""
                isAddingStream = false
            },
            onCancel: {
                isAddingStream = false
            }
        )
    }
}

// MARK: SidebarView.swift
struct StreamRow: View {
    let stream: StreamConnection
    @EnvironmentObject var streamManager: StreamManager
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(streamManager.isConnected ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 7, height: 7)
                .padding(.leading, 3)
            Text(stream.name)
                .lineLimit(1)
                .padding(.leading, 2)
        }
        .padding(.vertical, 2)
    }
}

struct AddStreamSheet: View {
    @Binding var name: String
    @Binding var url: String
    var onAdd: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Stream")
                .font(.headline)
            
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
            
            TextField("URL", text: $url)
                .textFieldStyle(.roundedBorder)
            
            buttonRow
        }
        .padding()
        .frame(width: 300)
    }
    
    private var buttonRow: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Add", action: onAdd)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || url.isEmpty)
        }
    }
}
