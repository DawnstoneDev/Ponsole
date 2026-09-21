import Foundation
import SwiftUI

enum LogLevel: String, CaseIterable, Sendable {
    case error
    case warning
    case info
    case debug

    var title: String {
        switch self {
        case .error:
            return "エラー"
        case .warning:
            return "警告"
        case .info:
            return "情報"
        case .debug:
            return "デバッグ"
        }
    }

    var systemImage: String {
        switch self {
        case .error:
            return "xmark.octagon.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        case .debug:
            return "ant.fill"
        }
    }

    var color: Color {
        switch self {
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .secondary
        case .debug:
            return .blue
        }
    }

    static func detect(from message: String) -> LogLevel {
        let value = message
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        if value.hasPrefix("[error]") ||
            value.hasPrefix("error:") ||
            value.hasPrefix("error ") ||
            value.hasPrefix("fault:") ||
            value.hasPrefix("critical:") {
            return .error
        }

        if value.hasPrefix("[warning]") ||
            value.hasPrefix("warning:") ||
            value.hasPrefix("warning ") ||
            value.hasPrefix("warn:") {
            return .warning
        }

        if value.hasPrefix("[debug]") ||
            value.hasPrefix("debug:") ||
            value.hasPrefix("debug ") {
            return .debug
        }

        return .info
    }
}

struct LogEntry: Identifiable, Hashable, Sendable {
    let id: Int
    let lineNumber: Int
    let timestamp: String
    let deviceName: String
    let process: String
    let pid: String
    let message: String
    let rawLine: String

    init(
        lineNumber: Int,
        timestamp: String,
        deviceName: String,
        process: String,
        pid: String,
        message: String,
        rawLine: String
    ) {
        self.id = lineNumber
        self.lineNumber = lineNumber
        self.timestamp = timestamp
        self.deviceName = deviceName
        self.process = process
        self.pid = pid
        self.message = message
        self.rawLine = rawLine
    }
}

struct LogDocument: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL

    init(
        id: UUID = UUID(),
        url: URL
    ) {
        self.id = id
        self.url = url
    }

    var fileName: String {
        url.lastPathComponent
    }

    var fileExtension: String {
        url.pathExtension.uppercased()
    }
}

enum LogFilter: String, CaseIterable, Hashable, Sendable {
    case all
    case errors
    case warnings
    case info
    case debug

    var title: String {
        switch self {
        case .all:
            return "すべて"
        case .errors:
            return "エラー"
        case .warnings:
            return "警告"
        case .info:
            return "情報"
        case .debug:
            return "デバッグ"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease.circle"
        case .errors:
            return "xmark.octagon.fill"
        case .warnings:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        case .debug:
            return "ant.fill"
        }
    }

    func matches(
        _ level: LogLevel
    ) -> Bool {
        switch self {
        case .all:
            return true
        case .errors:
            return level == .error
        case .warnings:
            return level == .warning
        case .info:
            return level == .info
        case .debug:
            return level == .debug
        }
    }
}

enum SidebarSelection: Hashable {
    case log(UUID)
    case filter(LogFilter)
}
