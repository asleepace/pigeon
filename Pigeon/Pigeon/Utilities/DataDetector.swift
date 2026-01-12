//
//  DataDetector.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//
//  Detects and categorizes different data types in event payloads.
//

import Foundation
import SwiftUI

enum DataType: Equatable {
    case json
    case jsonArray
    case url
    case timestamp
    case number
    case boolean
    case error
    case stackTrace
    case plainText
}

enum DataDetector {

    /// Detect the type of data in a string
    static func detect(_ string: String?) -> DataType {
        guard let string = string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else {
            return .plainText
        }

        // Check for JSON object
        if string.hasPrefix("{") && string.hasSuffix("}") {
            if isValidJSON(string) {
                // Check if it looks like an error
                if containsErrorIndicators(string) {
                    return .error
                }
                return .json
            }
        }

        // Check for JSON array
        if string.hasPrefix("[") && string.hasSuffix("]") {
            if isValidJSON(string) {
                return .jsonArray
            }
        }

        // Check for URL
        if isURL(string) {
            return .url
        }

        // Check for timestamp/date
        if isTimestamp(string) {
            return .timestamp
        }

        // Check for boolean
        if string.lowercased() == "true" || string.lowercased() == "false" {
            return .boolean
        }

        // Check for number
        if isNumber(string) {
            return .number
        }

        // Check for stack trace
        if isStackTrace(string) {
            return .stackTrace
        }

        // Check for error-like text
        if containsErrorIndicators(string) {
            return .error
        }

        return .plainText
    }

    /// Check if string is valid JSON
    static func isValidJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    /// Check if string is a URL
    static func isURL(_ string: String) -> Bool {
        if string.hasPrefix("http://") || string.hasPrefix("https://") {
            return URL(string: string) != nil
        }
        return false
    }

    /// Check if string is a timestamp
    static func isTimestamp(_ string: String) -> Bool {
        // ISO 8601 format
        let iso8601Pattern = #"^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}"#
        if string.range(of: iso8601Pattern, options: .regularExpression) != nil {
            return true
        }

        // Unix timestamp (10 or 13 digits)
        if let _ = Double(string), string.count == 10 || string.count == 13 {
            return true
        }

        return false
    }

    /// Check if string is a number
    static func isNumber(_ string: String) -> Bool {
        Double(string) != nil
    }

    /// Check if string looks like a stack trace
    static func isStackTrace(_ string: String) -> Bool {
        let indicators = ["at ", "Error:", "Exception", ".swift:", ".js:", "line "]
        let lineCount = string.components(separatedBy: "\n").count
        return lineCount > 2 && indicators.contains { string.contains($0) }
    }

    /// Check for error indicators
    static func containsErrorIndicators(_ string: String) -> Bool {
        let lowered = string.lowercased()
        let errorWords = ["error", "exception", "failed", "failure", "crash", "fatal"]
        return errorWords.contains { lowered.contains($0) }
    }

    /// Get display color for data type
    static func color(for type: DataType) -> Color {
        switch type {
        case .json, .jsonArray: return .primary
        case .url: return AppTheme.Colors.url
        case .timestamp: return AppTheme.Colors.number
        case .number: return AppTheme.Colors.number
        case .boolean: return AppTheme.Colors.boolean
        case .error, .stackTrace: return .red
        case .plainText: return .primary
        }
    }

    /// Get SF Symbol for data type
    static func icon(for type: DataType) -> String {
        switch type {
        case .json: return "curlybraces"
        case .jsonArray: return "list.number"
        case .url: return "link"
        case .timestamp: return "clock"
        case .number: return "number"
        case .boolean: return "switch.2"
        case .error: return "exclamationmark.triangle"
        case .stackTrace: return "list.bullet.rectangle"
        case .plainText: return "text.alignleft"
        }
    }
}
