//
//  JSONFormatter.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//
//  Smart JSON formatting with syntax highlighting support.
//

import Foundation
import SwiftUI

enum JSONFormatter {

    /// Format a JSON string with pretty printing
    static func format(_ string: String) -> String {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let formatted = String(data: pretty, encoding: .utf8) else {
            return string
        }
        return formatted
    }

    /// Format any JSON-compatible object
    static func format(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return String(describing: object)
        }
        return string
    }

    /// Parse a JSON string into an array
    static func parseArray(_ string: String?) -> [Any]? {
        guard let string, let data = string.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [Any]
    }

    /// Parse a JSON string into a dictionary
    static func parseDictionary(_ string: String?) -> [String: Any]? {
        guard let string, let data = string.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Format a value for inline preview
    static func formatPreview(_ value: Any, maxLength: Int = 50) -> String {
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
            return formatInlineDictionary(dict, maxLength: maxLength)
        case let array as [Any]:
            return formatInlineArray(array, maxLength: maxLength)
        default:
            return String(describing: value)
        }
    }

    /// Format dictionary for inline display
    static func formatInlineDictionary(_ dict: [String: Any], maxLength: Int) -> String {
        let pairs = dict.map { "\($0.key): \(formatInlineValue($0.value))" }
        let full = "{ " + pairs.joined(separator: ", ") + " }"
        if full.count <= maxLength { return full }
        return String(full.prefix(maxLength - 1)) + "…"
    }

    /// Format array for inline display
    static func formatInlineArray(_ array: [Any], maxLength: Int) -> String {
        let items = array.map { formatInlineValue($0) }
        let full = "[" + items.joined(separator: ", ") + "]"
        if full.count <= maxLength { return full }
        return String(full.prefix(maxLength - 1)) + "…"
    }

    /// Format a single value for inline display
    static func formatInlineValue(_ value: Any) -> String {
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

    /// Get color for a primitive value type
    static func colorForValue(_ value: Any) -> Color {
        switch value {
        case is String: return AppTheme.Colors.string
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return AppTheme.Colors.boolean
            }
            return AppTheme.Colors.number
        case is NSNull: return AppTheme.Colors.null
        default: return .primary
        }
    }

    /// Check if a value is a primitive type
    static func isPrimitive(_ value: Any) -> Bool {
        switch value {
        case is String, is NSNumber, is NSNull:
            return true
        default:
            return false
        }
    }
}
