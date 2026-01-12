//
//  TextEventListView.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import SwiftUI

// MARK: - Reusable Components

struct CodeLine: View {
    var code: String

    var body: some View {
        Text(code)
            .font(AppTheme.Fonts.monoMedium)
            .foregroundColor(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .textSelection(.enabled)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }
}

struct CodeBlock: View {
    var code: String

    var body: some View {
        HStack {
            Text(code)
                .font(AppTheme.Fonts.monoMedium)
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
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var streamName: String
    var streamUrl: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4.0)
            ContentUnavailableView(
                streamName,
                systemImage: "antenna.radiowaves.left.and.right",
                description: Text("Waiting for incoming events. Send an HTTP request to get started:")
            )
            CodeLine(code: "curl -d \"hello, world\" \(streamUrl)")
            Spacer(minLength: 4.0)
            Button("Send Test Event") {
                Task {
                    await sendTestEvent()
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer(minLength: 4.0)
        }
    }

    private func sendTestEvent() async {
        do {
            _ = try await fetch(
                streamUrl,
                method: .POST,
                headers: ["Content-Type": "text/plain"],
                body: "Hello, world!".data(using: .utf8)
            )
        } catch {
            // Test event failed to send
        }
    }
}

// MARK: - Search Filter Bar

struct SearchFilterBar: View {
    @Binding var searchQuery: String
    @Binding var filterType: String?
    var eventCount: Int

    private let filterOptions = ["All", "message", "system", "error"]

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search events...", text: $searchQuery)
                    .textFieldStyle(.plain)
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(AppTheme.CornerRadius.small)

            // Filter dropdown
            Picker("Filter", selection: Binding(
                get: { filterType ?? "All" },
                set: { filterType = $0 == "All" ? nil : $0 }
            )) {
                ForEach(filterOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            Spacer()

            // Event count
            Text("\(eventCount) events")
                .font(AppTheme.Fonts.monoSmall)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(.bar)
    }
}

// MARK: - Connection Status View

struct ConnectionStatusView: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            if case .reconnecting(let attempt) = state {
                Text("Reconnecting (\(attempt))...")
                    .font(AppTheme.Fonts.monoSmall)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var statusColor: Color {
        switch state {
        case .connected: return AppTheme.Colors.connected
        case .connecting: return AppTheme.Colors.connecting
        case .reconnecting: return AppTheme.Colors.reconnecting
        case .disconnected: return AppTheme.Colors.disconnected
        case .failed: return AppTheme.Colors.failed
        }
    }
}

// MARK: - Main View

struct TextEventListView: View {
    let stream: StreamConnection
    @EnvironmentObject var streamManager: StreamManager
    @State private var isSearchVisible: Bool = false

    var messages: [TextEvent] {
        streamManager.events(for: stream.url).filter { event in
            // Filter by type (only show message type by default unless filtering)
            if streamManager.filterType == nil {
                return event.type == "message"
            }
            return event.type == streamManager.filterType
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search/filter bar (toggleable)
            if isSearchVisible {
                SearchFilterBar(
                    searchQuery: $streamManager.searchQuery,
                    filterType: $streamManager.filterType,
                    eventCount: messages.count
                )
                Divider()
            }

            // Event list
            ScrollViewReader { proxy in
                if messages.isEmpty {
                    EmptyStateView(streamName: stream.name, streamUrl: stream.url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(messages) { event in
                                TextEventView(event: event)
                                    .id(event.id)
                                Divider()
                                    .padding(.leading, 10)
                            }
                        }
                        .padding(.top, 1)
                    }
                    .onChange(of: streamManager.events(for: stream.url).count) { _, _ in
                        if let lastEvent = messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastEvent.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(stream.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ConnectionStatusView(state: streamManager.connectionState)
                    .padding(.leading, 16.0)
                    .padding(.trailing, 4.0)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isSearchVisible.toggle()
                    }
                } label: {
                    Image(systemName: isSearchVisible ? "magnifyingglass.circle.fill" : "magnifyingglass")
                }
                .help("Toggle search")

                Button {
                    streamManager.clearEvents(for: stream.url)
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
        }
    }
}
