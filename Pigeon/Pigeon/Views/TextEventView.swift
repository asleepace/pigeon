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
    @State private var isHovering: Bool = false

    // MARK: - Computed Properties

    private var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: event.timestamp)
    }

    private var dataType: DataType {
        DataDetector.detect(event.data)
    }

    private var isSystemEvent: Bool {
        event.type == "system"
    }

    private var parsedArray: [Any]? {
        JSONFormatter.parseArray(event.data)
    }

    private var parsedDictionary: [String: Any]? {
        JSONFormatter.parseDictionary(event.data)
    }

    private var hasComplexContent: Bool {
        if isSystemEvent || dataType == .json || dataType == .jsonArray { return true }
        guard let array = parsedArray else { return false }
        return array.contains { !JSONFormatter.isPrimitive($0) }
    }

    private var preview: String {
        if isSystemEvent || dataType == .json {
            if let dict = parsedDictionary {
                return JSONFormatter.formatPreview(dict, maxLength: 80)
            }
            return event.data ?? "—"
        }
        guard let array = parsedArray else {
            return event.data ?? "—"
        }
        return array.map { JSONFormatter.formatPreview($0) }.joined(separator: " ")
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow

            if isExpanded && hasComplexContent {
                expandedContent
                    .padding(.leading, 32)
                    .padding(.trailing, AppTheme.Spacing.lg)
                    .padding(.top, AppTheme.Spacing.xs)
                    .padding(.bottom, AppTheme.Spacing.md)
            }
        }
        .background(isExpanded ? AppTheme.Colors.expandedBackground : Color.clear)
        .clipShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.md) {
            // Expand chevron (clickable)
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
                    .opacity(hasComplexContent ? 1 : 0.3)
            }
            .buttonStyle(.plain)

            // Timestamp
            Text(timestamp)
                .font(AppTheme.Fonts.mono)
                .foregroundColor(.secondary)
                .textSelection(.enabled)

            // Type badge
            typeBadge

            // Preview content
            Text(preview)
                .font(AppTheme.Fonts.mono)
                .foregroundColor(DataDetector.color(for: dataType))
                .lineLimit(isExpanded ? nil : 1)
                .truncationMode(.tail)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    private var typeBadge: some View {
        Group {
            switch dataType {
            case .json:
                Text("{}")
                    .font(AppTheme.Fonts.monoBold)
            case .jsonArray:
                Text("[]")
                    .font(AppTheme.Fonts.monoBold)
            default:
                Image(systemName: DataDetector.icon(for: dataType))
                    .font(.system(size: 8))
            }
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.15))
        .cornerRadius(3)
    }

    private var copyButton: some View {
        Button {
            if let data = event.data {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(data, forType: .string)
            }
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help("Copy to clipboard")
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                if let dict = parsedDictionary {
                    JSONTreeView(object: dict)
                } else if let array = parsedArray {
                    expandedArrayContent(array)
                } else {
                    codeBlock(event.data ?? "")
                }
            }
            .codeBlockStyle()

            // Copy button in top right
            copyButton
                .padding(AppTheme.Spacing.sm)
        }
    }

    private func expandedArrayContent(_ array: [Any]) -> some View {
        JSONArrayView(array: array, showBrackets: true)
    }

    private func codeBlock(_ text: String) -> some View {
        Text(JSONFormatter.format(text))
            .font(AppTheme.Fonts.mono)
            .textSelection(.enabled)
    }
}

// MARK: - JSON Tree View (Chrome DevTools-like)

struct JSONTreeView: View {
    let object: [String: Any]
    var showBrackets: Bool = true
    @State private var expandedKeys: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if showBrackets {
                Text("{")
                    .font(AppTheme.Fonts.mono)
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                let sortedKeys = object.keys.sorted()
                ForEach(Array(sortedKeys.enumerated()), id: \.element) { index, key in
                    JSONKeyValueRow(
                        key: key,
                        value: object[key]!,
                        isExpanded: expandedKeys.contains(key),
                        isLast: index == sortedKeys.count - 1,
                        onToggle: { toggleKey(key) }
                    )
                }
            }
            .padding(.leading, showBrackets ? 12 : 0)
            if showBrackets {
                Text("}")
                    .font(AppTheme.Fonts.mono)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func toggleKey(_ key: String) {
        if expandedKeys.contains(key) {
            expandedKeys.remove(key)
        } else {
            expandedKeys.insert(key)
        }
    }
}

struct JSONKeyValueRow: View {
    let key: String
    let value: Any
    let isExpanded: Bool
    var isLast: Bool = false
    let onToggle: () -> Void

    private var isExpandable: Bool {
        value is [String: Any] || value is [Any]
    }

    private var valuePreview: String {
        if let dict = value as? [String: Any] {
            return "{\(dict.count)}"
        } else if let array = value as? [Any] {
            return "[\(array.count)]"
        }
        return JSONFormatter.formatPreview(value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                // Expand chevron
                if isExpandable {
                    Button(action: onToggle) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 16)
                }

                // Key
                Text(key)
                    .font(AppTheme.Fonts.mono)
                    .foregroundColor(AppTheme.Colors.key)

                Text(":")
                    .font(AppTheme.Fonts.mono)
                    .foregroundColor(.secondary)

                // Value or preview
                if !isExpanded || !isExpandable {
                    HStack(spacing: 0) {
                        Text(valuePreview)
                            .font(AppTheme.Fonts.mono)
                            .foregroundColor(JSONFormatter.colorForValue(value))
                            .textSelection(.enabled)
                        if !isLast {
                            Text(",")
                                .font(AppTheme.Fonts.mono)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(.vertical, 1)

            // Expanded nested content
            if isExpanded && isExpandable {
                Group {
                    if let dict = value as? [String: Any] {
                        JSONTreeView(object: dict)
                    } else if let array = value as? [Any] {
                        JSONArrayView(array: array)
                    }
                }
                .padding(.leading, 16)
            }
        }
    }
}

struct JSONArrayView: View {
    let array: [Any]
    var showBrackets: Bool = true

    // Check if array contains only primitive values of the same type
    private var isHomogeneous: Bool {
        guard !array.isEmpty else { return true }
        let firstType = type(of: array[0])
        return array.allSatisfy { type(of: $0) == firstType && JSONFormatter.isPrimitive($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if showBrackets {
                Text("[")
                    .font(AppTheme.Fonts.mono)
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(array.enumerated()), id: \.offset) { index, item in
                    let isLast = index == array.count - 1
                    let showComma = isHomogeneous && !isLast
                    if let dict = item as? [String: Any] {
                        JSONTreeView(object: dict, showBrackets: true)
                    } else if let arr = item as? [Any] {
                        JSONArrayView(array: arr, showBrackets: true)
                    } else {
                        HStack(spacing: 0) {
                            Text(JSONFormatter.formatPreview(item))
                                .font(AppTheme.Fonts.mono)
                                .foregroundColor(JSONFormatter.colorForValue(item))
                                .textSelection(.enabled)
                            if showComma {
                                Text(",")
                                    .font(AppTheme.Fonts.mono)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .padding(.leading, showBrackets ? 12 : 0)
            if showBrackets {
                Text("]")
                    .font(AppTheme.Fonts.mono)
                    .foregroundColor(.secondary)
            }
        }
    }
}
