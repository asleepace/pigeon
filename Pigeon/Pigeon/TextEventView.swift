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
    
    private var isSystemEvent: Bool {
        event.type == "system"
    }
    
    private var parsedArray: [Any]? {
        guard let data = event.data?.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [Any]
    }
    
    private var hasComplexContent: Bool {
        if isSystemEvent { return true }
        guard let array = parsedArray else { return false }
        return array.contains { !isPrimitive($0) }
    }
    
    private func isPrimitive(_ value: Any) -> Bool {
        switch value {
        case is String, is NSNumber, is NSNull:
            return true
        default:
            return false
        }
    }
    
    private var preview: String {
        if isSystemEvent {
            return event.data ?? "—"
        }
        guard let array = parsedArray else {
            return event.data ?? "—"
        }
        return array.map { formatPreview($0) }.joined(separator: " ")
    }
    
    private func formatPreview(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        case is NSNull:
            return "null"
        case let dict as [String: Any]:
            return formatInline(dict, maxLength: 60)
        case let array as [Any]:
            return formatInline(array, maxLength: 60)
        default:
            return String(describing: value)
        }
    }

    private func formatInline(_ dict: [String: Any], maxLength: Int) -> String {
        let pairs = dict.map { "\($0.key): \(formatInlineValue($0.value))" }
        let full = "{ " + pairs.joined(separator: ", ") + " }"
        if full.count <= maxLength {
            return full
        }
        return String(full.prefix(maxLength - 1)) + "…"
    }

    private func formatInline(_ array: [Any], maxLength: Int) -> String {
        let items = array.map { formatInlineValue($0) }
        let full = "[" + items.joined(separator: ", ") + "]"
        if full.count <= maxLength {
            return full
        }
        return String(full.prefix(maxLength - 1)) + "…"
    }

    private func formatInlineValue(_ value: Any) -> String {
        switch value {
        case let string as String:
            return "\"\(string)\""
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        case is NSNull:
            return "null"
        case let dict as [String: Any]:
            let pairs = dict.map { "\($0.key): \(formatInlineValue($0.value))" }
            return "{ " + pairs.joined(separator: ", ") + " }"
        case let array as [Any]:
            let items = array.map { formatInlineValue($0) }
            return "[" + items.joined(separator: ", ") + "]"
        default:
            return String(describing: value)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12)
                        .opacity(hasComplexContent ? 1 : 0.3)
                    
                    Text(timestamp)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text(event.type ?? "message")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(badgeColor)
                        .foregroundColor(badgeTextColor)
                        .cornerRadius(3)
                    
                    Text(preview)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 1)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded && hasComplexContent {
                expandedContent
                    .padding(.leading, 28)
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isExpanded ? Color.gray.opacity(0.08) : Color.clear)
    }
    
    @ViewBuilder
    private var expandedContent: some View {
        if isSystemEvent {
            codeBlock(formatJSON(event.data ?? ""))
        } else if let array = parsedArray {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(array.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .trailing)
                        
                        if isPrimitive(item) {
                            Text(formatPreview(item))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(colorForPrimitive(item))
                                .textSelection(.enabled)
                        } else {
                            Text(formatJSON(item))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.15))
            .cornerRadius(4)
        }
    }
    
    private func codeBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .textSelection(.enabled)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.15))
            .cornerRadius(4)
    }
    
    private func colorForPrimitive(_ value: Any) -> Color {
        switch value {
        case is String:
            return .green
        case is NSNumber:
            return .blue
        case is NSNull:
            return .secondary
        default:
            return .primary
        }
    }
    
    private var badgeColor: Color {
        switch event.type?.lowercased() {
        case "system": return .orange
        case "error": return .red
        case "warn", "warning": return .yellow
        default: return Color.gray.opacity(0.3)
        }
    }
    
    private var badgeTextColor: Color {
        switch event.type?.lowercased() {
        case "system", "error": return .white
        case "warn", "warning": return .black
        default: return .primary
        }
    }
    
    private func formatJSON(_ string: String) -> String {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let formatted = String(data: pretty, encoding: .utf8)
        else { return string }
        return formatted
    }
    
    private func formatJSON(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8)
        else { return String(describing: object) }
        return string
    }
}
