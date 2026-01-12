//
//  SidebarView.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//
//  Displays left-hand sidebar with list of stream connections.
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var streamManager: StreamManager
    @Binding var selectedStream: StreamConnection?
    @State private var streams: [StreamConnection] = StreamStorage.load()
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
            if let stream = newStream, let url = URL(string: stream.url) {
                streamManager.connect(to: url)
            }
        }
        .onChange(of: streams) { _, newStreams in
            StreamStorage.save(newStreams)
        }
        .onAppear {
            guard selectedStream == nil else { return }
            selectedStream = streams.first
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
