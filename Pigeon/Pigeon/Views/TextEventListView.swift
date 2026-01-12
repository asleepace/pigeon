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

// MARK: - Unified Toolbar

struct UnifiedToolbar: View {
    let stream: StreamConnection
    @Binding var searchQuery: String
    @Binding var filterType: String?
    var eventCount: Int
    var connectionState: ConnectionState
    var isConnected: Bool
    var onClear: () -> Void
    var onToggleConnection: () -> Void

    private let filterOptions = ["All", "message", "system", "error"]

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            // Connection status
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            if case .reconnecting(let attempt) = connectionState {
                Text("(\(attempt))")
                    .font(AppTheme.Fonts.monoSmall)
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(height: 16)

            // Search field
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                TextField("Filter", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 60, maxWidth: 120)
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)

            // Type filter
            Picker("", selection: Binding(
                get: { filterType ?? "All" },
                set: { filterType = $0 == "All" ? nil : $0 }
            )) {
                ForEach(filterOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            .labelsHidden()

            Spacer()

            // Event count
            Text("\(eventCount)")
                .font(AppTheme.Fonts.monoSmall)
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 16)

            // Action buttons
            Button(action: onClear) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Clear events")

            Button(action: onToggleConnection) {
                Image(systemName: isConnected ? "pause.fill" : "play.fill")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help(isConnected ? "Disconnect" : "Connect")
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var statusColor: Color {
        switch connectionState {
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
            // Unified toolbar
            UnifiedToolbar(
                stream: stream,
                searchQuery: $streamManager.searchQuery,
                filterType: $streamManager.filterType,
                eventCount: messages.count,
                connectionState: streamManager.connectionState,
                isConnected: streamManager.isConnected,
                onClear: { streamManager.clearEvents(for: stream.url) },
                onToggleConnection: {
                    if streamManager.isConnected {
                        streamManager.disconnect()
                    } else if let url = URL(string: stream.url) {
                        streamManager.connect(to: url)
                    }
                }
            )

            Divider()

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
    }
}
