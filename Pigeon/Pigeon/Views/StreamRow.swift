//
//  StreamRow.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import SwiftUI

struct StreamRow: View {
    let stream: StreamConnection
    @EnvironmentObject var streamManager: StreamManager

    private var isThisStreamConnected: Bool {
        guard streamManager.isConnected else { return false }
        return streamManager.url?.absoluteString == stream.url
    }

    private var statusColor: Color {
        switch streamManager.connectionState {
        case .connected where streamManager.url?.absoluteString == stream.url:
            return .green
        case .connecting where streamManager.url?.absoluteString == stream.url:
            return .yellow
        case .reconnecting where streamManager.url?.absoluteString == stream.url:
            return .orange
        case .failed where streamManager.url?.absoluteString == stream.url:
            return .red
        default:
            return .gray.opacity(0.5)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .padding(.leading, 3)
            Text(stream.name)
                .lineLimit(1)
                .padding(.leading, 2)
        }
        .padding(.vertical, 2)
    }
}
