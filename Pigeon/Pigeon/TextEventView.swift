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
            return event.data ?? "—-"
        }
        guard let array = parsedArray else {
            return event.data ?? "—-"
        }
        return array.map { formatPreview($0) }.joined(separator: " ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            
            if isExpanded && hasComplexContent {
                expandedContent
                    .padding(.leading, 32)
                    .padding(.trailing, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
        }
        .background(isExpanded ? Color.gray.opacity(0.08) : Color.clear)
    }
    
    // MARK: - Header Row
    
    private var headerRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)
                    .opacity(hasComplexContent ? 1 : 0.3)
                
                Text(timestamp)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                
                // badgeView
                
                Text(preview)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 1)
                    .truncationMode(.tail)
                
                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
//    private var badgeView: some View {
//        Text(event.type ?? "message")
//            .font(.system(size: 9, weight: .medium, design: .monospaced))
//            .padding(.horizontal, 5)
//            .padding(.vertical, 2)
//            .background(badgeColor)
//            .foregroundColor(badgeTextColor)
//            .cornerRadius(3)
//    }
    
    // MARK: - Expanded Content
    
    @ViewBuilder
    private var expandedContent: some View {
        if isSystemEvent {
            codeBlock(formatJSON(event.data ?? ""))
        } else if let array = parsedArray {
            expandedArrayContent(array)
        }
    }
    
    private func expandedArrayContent(_ array: [Any]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(array.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 6) {
                    
//                    if depth > 0 {
//                        Text("\(index)")
//                            .font(.system(size: 10, design: .monospaced))
//                            .foregroundColor(.secondary)
//                            .frame(width: 14, alignment: .trailing)
//                    }
                    
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
                .focusable(true, interactions: .automatic)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.2))
        .cornerRadius(4)
    }
    
    private func codeBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .textSelection(.enabled)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.2))
            .cornerRadius(4)
    }
    
    // MARK: - Formatting
    
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
            return formatInline(dict, maxLength: 50)
        case let array as [Any]:
            return formatInline(array, maxLength: 50)
        default:
            return String(describing: value)
        }
    }
    
    private func formatInline(_ dict: [String: Any], maxLength: Int) -> String {
        let pairs = dict.map { "\($0.key): \(formatInlineValue($0.value))" }
        let full = "{ " + pairs.joined(separator: ", ") + " }"
        if full.count <= maxLength { return full }
        return String(full.prefix(maxLength - 1)) + "…"
    }
    
    private func formatInline(_ array: [Any], maxLength: Int) -> String {
        let items = array.map { formatInlineValue($0) }
        let full = "[" + items.joined(separator: ", ") + "]"
        if full.count <= maxLength { return full }
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
            return "{ \(dict.count) }"
        case let array as [Any]:
            return "[\(array.count)]"
        default:
            return String(describing: value)
        }
    }
    
    private func colorForPrimitive(_ value: Any) -> Color {
        switch value {
        case is String: return .green
        case is NSNumber: return .cyan
        case is NSNull: return .secondary
        default: return .primary
        }
    }
    
    private var badgeColor: Color {
        switch event.type?.lowercased() {
        case "system": return .orange
        case "error": return .red
        case "warn", "warning": return .yellow
        default: return Color(nsColor: .darkGray)
        }
    }
    
    private var badgeTextColor: Color {
        switch event.type?.lowercased() {
        case "warn", "warning": return .black
        default: return .white
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
