//
//  TextEventView.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//
import SwiftUI

struct TextEventView: View {
    let event: TextEvent
    @State private var isExpanded: Bool = false
    
    private var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: event.timestamp)
    }
    
    private var preview: String {
        event.data?.components(separatedBy: .newlines).first ?? "—"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(alignment: .top, spacing: 8) {
                // Expand chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 12)
                
                // Timestamp
                Text(timestamp)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                
                // Event type badge
                if let eventType = event.type {
                    Text(eventType)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(badgeColor(for: eventType))
                        .foregroundColor(.white)
                        .cornerRadius(3)
                }
                
                // Preview / message
                Text(preview)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if !event.id.isEmpty {
                        detailRow("id", event.id)
                    }
                    if let eventType = event.type {
                        detailRow("event", eventType)
                    }
                    if let data = event.data {
                        Text(formatJSON(data))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .padding(.leading, 28)
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
        }
        .background(isExpanded ? Color.gray.opacity(0.1) : Color.clear)
    }
    
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
    
    private func badgeColor(for event: String) -> Color {
        switch event.lowercased() {
        case "error": return .red
        case "warn", "warning": return .orange
        case "info": return .blue
        case "debug": return .gray
        default: return .purple
        }
    }
    
    private func formatJSON(_ string: String) -> String {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let formatted = String(data: pretty, encoding: .utf8)
        else { return string }
        return formatted
    }
}
