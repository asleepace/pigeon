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
        formatter.dateFormat = "HH:mm:ss.SSS"
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
                    .frame(width: 10)
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

            // Copy button (shown on hover)
            if isHovering {
                copyButton
            }
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
    }

    private func expandedArrayContent(_ array: [Any]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
            ForEach(Array(array.enumerated()), id: \.offset) { _, item in
                if JSONFormatter.isPrimitive(item) {
                    Text(JSONFormatter.formatPreview(item))
                        .font(AppTheme.Fonts.mono)
                        .foregroundColor(JSONFormatter.colorForValue(item))
                        .textSelection(.enabled)
                } else if let dict = item as? [String: Any] {
                    JSONTreeView(object: dict)
                } else {
                    Text(JSONFormatter.format(item))
                        .font(AppTheme.Fonts.mono)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                }
            }
        }
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
    @State private var expandedKeys: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(object.keys.sorted(), id: \.self) { key in
                JSONKeyValueRow(
                    key: key,
                    value: object[key]!,
                    isExpanded: expandedKeys.contains(key),
                    onToggle: { toggleKey(key) }
                )
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
                            .frame(width: 10)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 10)
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
                    Text(valuePreview)
                        .font(AppTheme.Fonts.mono)
                        .foregroundColor(JSONFormatter.colorForValue(value))
                        .textSelection(.enabled)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(array.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 4) {
                    Text("\(index)")
                        .font(AppTheme.Fonts.monoSmall)
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .trailing)

                    if let dict = item as? [String: Any] {
                        JSONTreeView(object: dict)
                    } else {
                        Text(JSONFormatter.formatPreview(item))
                            .font(AppTheme.Fonts.mono)
                            .foregroundColor(JSONFormatter.colorForValue(item))
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}
