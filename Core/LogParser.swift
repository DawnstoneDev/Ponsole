import Foundation

struct LogPageResult: Sendable {
    let entries: [LogEntry]
    let hasMore: Bool
}

enum LogParserError: LocalizedError {
    case directory(URL)
    case unreadable(URL)

    var errorDescription: String? {
        switch self {
        case .directory(let url):
            return "\(url.lastPathComponent) はフォルダです。ログファイルを選択してください。"

        case .unreadable(let url):
            return "\(url.lastPathComponent) を読み込めませんでした。"
        }
    }
}

enum LogParser {
    private static let monthNumbers: [String: Int] = [
        "Jan": 1,
        "Feb": 2,
        "Mar": 3,
        "Apr": 4,
        "May": 5,
        "Jun": 6,
        "Jul": 7,
        "Aug": 8,
        "Sep": 9,
        "Oct": 10,
        "Nov": 11,
        "Dec": 12
    ]

    private static let weekdays: Set<String> = [
        "Mon",
        "Tue",
        "Wed",
        "Thu",
        "Fri",
        "Sat",
        "Sun"
    ]

    static func readPage(
        url: URL,
        filter: LogFilter,
        searchText: String,
        page: Int,
        pageSize: Int
    ) async throws -> LogPageResult {
        guard !url.hasDirectoryPath else {
            throw LogParserError.directory(url)
        }

        guard FileManager.default.fileExists(
            atPath: url.path
        ) else {
            throw LogParserError.unreadable(url)
        }

        let normalizedSearch = searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let pageStart = page * pageSize
        let pageEnd = pageStart + pageSize

        var entries: [LogEntry] = []
        entries.reserveCapacity(pageSize)

        var lineNumber = 0
        var matchedCount = 0

        do {
            for try await line in url.lines {
                try Task.checkCancellation()

                lineNumber += 1

                guard !line.isEmpty else {
                    continue
                }

                guard matches(
                    line: line,
                    filter: filter,
                    searchText: normalizedSearch
                ) else {
                    continue
                }

                if matchedCount >= pageStart &&
                    matchedCount < pageEnd {

                    entries.append(
                        parseLine(
                            line,
                            lineNumber: lineNumber
                        )
                    )
                }

                matchedCount += 1

                if matchedCount >= pageEnd {
                    return LogPageResult(
                        entries: entries,
                        hasMore: true
                    )
                }

                if lineNumber.isMultiple(
                    of: 4096
                ) {
                    await Task.yield()
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw LogParserError.unreadable(url)
        }

        return LogPageResult(
            entries: entries,
            hasMore: false
        )
    }

    static func countMatches(
        url: URL,
        filter: LogFilter,
        searchText: String
    ) async throws -> Int {
        guard !url.hasDirectoryPath else {
            throw LogParserError.directory(url)
        }

        guard FileManager.default.fileExists(
            atPath: url.path
        ) else {
            throw LogParserError.unreadable(url)
        }

        let normalizedSearch = searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        var count = 0
        var lineNumber = 0

        do {
            for try await line in url.lines {
                try Task.checkCancellation()

                lineNumber += 1

                guard !line.isEmpty else {
                    continue
                }

                if matches(
                    line: line,
                    filter: filter,
                    searchText: normalizedSearch
                ) {
                    count += 1
                }

                if lineNumber.isMultiple(
                    of: 4096
                ) {
                    await Task.yield()
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw LogParserError.unreadable(url)
        }

        return count
    }

    private static func matches(
        line: String,
        filter: LogFilter,
        searchText: String
    ) -> Bool {
        let message = extractMessage(
            from: line
        )

        let level = LogLevel.detect(
            from: message
        )

        guard filter.matches(level) else {
            return false
        }

        guard !searchText.isEmpty else {
            return true
        }

        return line.localizedCaseInsensitiveContains(
            searchText
        )
    }

    private static func extractMessage(
        from line: String
    ) -> String {
        guard let separator = line.range(
            of: "]:"
        ) else {
            return line
        }

        return String(
            line[separator.upperBound...]
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private static func parseLine(
        _ line: String,
        lineNumber: Int
    ) -> LogEntry {
        if let structured =
            parseJamfStyleLine(
                line,
                lineNumber: lineNumber
            ) {
            return structured
        }

        return LogEntry(
            lineNumber: lineNumber,
            timestamp: "—",
            deviceName: "—",
            process: "—",
            pid: "—",
            message: line,
            rawLine: line
        )
    }

    private static func parseJamfStyleLine(
        _ line: String,
        lineNumber: Int
    ) -> LogEntry? {

        /*
         Jamf実際の形式:

         Wed Jul 30 21:17:01 KJTXR1Y1JK jamf[40648]: Error ...

         重要:
         「]:」を見つけても、プロセス部分から
         「]」を取り除かない。
        */

        guard let separator = line.range(
            of: "]:"
        ) else {
            return nil
        }

        // "]:" の前までではなく、
        // "]" を含めたプロセス部分まで取得する。
        let prefix = String(
            line[..<separator.upperBound]
        )
        .dropLast()

        let message = String(
            line[separator.upperBound...]
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let tokens = prefix
            .split(
                omittingEmptySubsequences: true, whereSeparator: \.isWhitespace
            )
            .map(String.init)

        guard let processToken = tokens.last else {
            return nil
        }

        let processInfo =
            parseProcessToken(
                processToken
            )

        let timestampInfo =
            parseTimestampAndDevice(tokens)

        return LogEntry(
            lineNumber: lineNumber,
            timestamp: timestampInfo.timestamp,
            deviceName: timestampInfo.deviceName,
            process: processInfo.process,
            pid: processInfo.pid,
            message: message,
            rawLine: line
        )
    }

    private static func parseProcessToken(
        _ token: String
    ) -> (
        process: String,
        pid: String
    ) {
        /*
         正常:

         jamf[40648]
         ↓
         process = jamf
         pid     = 40648
        */

        guard token.last == "]",
              let openingBracket =
                token.lastIndex(of: "[")
        else {
            return (
                process: token,
                pid: "—"
            )
        }

        let process =
            String(
                token[..<openingBracket]
            )

        let pidStart =
            token.index(
                after: openingBracket
            )

        let pidEnd =
            token.index(
                before: token.endIndex
            )

        let pid =
            String(
                token[pidStart..<pidEnd]
            )

        guard !process.isEmpty,
              !pid.isEmpty,
              pid.allSatisfy(\.isNumber)
        else {
            return (
                process: token,
                pid: "—"
            )
        }

        return (
            process: process,
            pid: pid
        )
    }

    private static func parseTimestampAndDevice(
        _ tokens: [String]
    ) -> (
        timestamp: String,
        deviceName: String
    ) {
        guard tokens.count >= 2 else {
            return (
                timestamp: "—",
                deviceName: "—"
            )
        }

        // Wed Jul 30 21:17:01 KJTXR1Y1JK jamf[40648]
        if tokens.count >= 6,
           weekdays.contains(tokens[0]),
           let month =
                monthNumbers[tokens[1]],
           let day =
                Int(tokens[2]) {

            return (
                timestamp:
                    "\(month)月\(day)日 \(tokens[3])",
                deviceName:
                    tokens[4]
            )
        }

        // Jul 30 21:17:01 KJTXR1Y1JK jamf[40648]
        if tokens.count >= 5,
           let month =
                monthNumbers[tokens[0]],
           let day =
                Int(tokens[1]) {

            return (
                timestamp:
                    "\(month)月\(day)日 \(tokens[2])",
                deviceName:
                    tokens[3]
            )
        }

        // 2026-07-30 21:17:01 KJTXR1Y1JK jamf[40648]
        if tokens.count >= 4,
           isDateToken(tokens[0]),
           isTimeToken(tokens[1]) {

            return (
                timestamp:
                    "\(formatISODate(tokens[0])) \(tokens[1])",
                deviceName:
                    tokens[2]
            )
        }

        // 2026-07-30T21:17:01 KJTXR1Y1JK jamf[40648]
        if tokens.count >= 3,
           let timestamp =
                parseCombinedISO(tokens[0]) {

            return (
                timestamp: timestamp,
                deviceName: tokens[1]
            )
        }

        return (
            timestamp: "—",
            deviceName: "—"
        )
    }

    private static func formatISODate(
        _ value: String
    ) -> String {
        let parts =
            value.split(
                separator: "-"
            )

        guard parts.count == 3,
              let month =
                Int(parts[1]),
              let day =
                Int(parts[2]) else {
            return value
        }

        return "\(month)月\(day)日"
    }

    private static func isDateToken(
        _ value: String
    ) -> Bool {
        let parts =
            value.split(
                separator: "-"
            )

        guard parts.count == 3 else {
            return false
        }

        return Int(parts[0]) != nil &&
            Int(parts[1]) != nil &&
            Int(parts[2]) != nil
    }

    private static func isTimeToken(
        _ value: String
    ) -> Bool {
        let parts =
            value.split(
                separator: ":"
            )

        guard parts.count == 3 else {
            return false
        }

        return parts.allSatisfy {
            Int($0) != nil
        }
    }

    private static func parseCombinedISO(
        _ value: String
    ) -> String? {
        guard let separator =
                value.firstIndex(of: "T")
        else {
            return nil
        }

        let dateText =
            String(
                value[..<separator]
            )

        let timeText =
            String(
                value[
                    value.index(
                        after: separator
                    )...
                ]
            )

        guard isDateToken(dateText) else {
            return nil
        }

        let cleanTime =
            String(
                timeText
                    .split(
                        separator: ".",
                        maxSplits: 1
                    )
                    .first
                ?? Substring(timeText)
            )

        guard isTimeToken(cleanTime) else {
            return nil
        }

        return "\(formatISODate(dateText)) \(cleanTime)"
    }
}
