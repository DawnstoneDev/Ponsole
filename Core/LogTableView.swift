import SwiftUI

@MainActor
struct LogTableView: View {
    let document: LogDocument
    let filter: LogFilter
    let searchText: String

    @Binding var selectedEntryIDs: Set<LogEntry.ID>

    private let pageSize = 2_000

    @State private var pageEntries: [LogEntry] = []

    @State private var totalCount: Int?
    @State private var hasMorePages = false
    @State private var currentPage = 0

    @State private var isPreparing = true

    @State private var countCache:
        [CountKey: Int] = [:]

    @State private var countTask:
        Task<Void, Never>?

    private struct PageKey: Hashable {
        let documentID: UUID
        let filter: LogFilter
        let searchText: String
        let page: Int
    }

    private struct CountKey: Hashable {
        let documentID: UUID
        let filter: LogFilter
        let searchText: String
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var pageKey: PageKey {
        PageKey(
            documentID: document.id,
            filter: filter,
            searchText: normalizedSearchText,
            page: currentPage
        )
    }

    private var countKey: CountKey {
        CountKey(
            documentID: document.id,
            filter: filter,
            searchText: normalizedSearchText
        )
    }

    private var pageCount: Int? {
        guard let totalCount else {
            return nil
        }

        guard totalCount > 0 else {
            return 1
        }

        return (
            totalCount + pageSize - 1
        ) / pageSize
    }

    private var firstDisplayedNumber: Int {
        guard !pageEntries.isEmpty else {
            return 0
        }

        return currentPage * pageSize + 1
    }

    private var lastDisplayedNumber: Int {
        guard !pageEntries.isEmpty else {
            return 0
        }

        return firstDisplayedNumber +
            pageEntries.count - 1
    }

    var body: some View {
        ZStack {
            tableContent
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .navigationTitle(
            "\(document.fileName) — \(filter.title)"
        )
        .safeAreaInset(edge: .bottom) {
            if shouldShowPageControls {
                pageControls
            }
        }
        .task(id: pageKey) {
            await loadCurrentPage()
        }
        .onChange(of: document.id) {
            currentPage = 0
            pageEntries.removeAll()
            totalCount = nil
            hasMorePages = false
            selectedEntryIDs.removeAll()
            countTask?.cancel()
            countTask = nil
        }
        .onChange(of: filter) {
            currentPage = 0
            pageEntries.removeAll()
            totalCount = nil
            hasMorePages = false
            selectedEntryIDs.removeAll()
            countTask?.cancel()
            countTask = nil
        }
        .onChange(of: searchText) {
            currentPage = 0
            pageEntries.removeAll()
            totalCount = nil
            hasMorePages = false
            selectedEntryIDs.removeAll()
            countTask?.cancel()
            countTask = nil
        }
        .onDisappear {
            countTask?.cancel()
            countTask = nil
        }
    }

    private var shouldShowPageControls: Bool {
        !pageEntries.isEmpty &&
        (
            hasMorePages ||
            currentPage > 0 ||
            totalCount != nil
        )
    }

    @ViewBuilder
    private var tableContent: some View {
        if isPreparing {
            VStack(spacing: 12) {
                ProgressView()

                Text("ログを読み込んでいます…")
                    .font(.headline)

                Text(
                    "\(document.fileName) — \(filter.title)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        } else if pageEntries.isEmpty {
            ContentUnavailableView(
                normalizedSearchText.isEmpty
                    ? "\(filter.title)のログはありません"
                    : "一致するログがありません",
                systemImage:
                    "line.3.horizontal.decrease.circle",
                description: Text(
                    normalizedSearchText.isEmpty
                        ? "\(document.fileName)には、このフィルターに一致するログがありません。"
                        : "\(document.fileName)の「\(normalizedSearchText)」に一致するログがありません。"
                )
            )
        } else {
            logTable
        }
    }

    private var logTable: some View {
        Table(
            pageEntries,
            selection: $selectedEntryIDs
        ) {
            TableColumn("時刻") { entry in
                Text(entry.timestamp)
                    .font(
                        .system(
                            .body,
                            design: .monospaced
                        )
                    )
                    .lineLimit(1)
            }
            .width(
                min: 140,
                ideal: 175,
                max: 210
            )

            TableColumn("種類") { entry in
                let level =
                    LogLevel.detect(
                        from: entry.message
                    )

                Label(
                    level.title,
                    systemImage:
                        level.systemImage
                )
                .lineLimit(1)
                .foregroundStyle(
                    level.color
                )
            }
            .width(
                min: 82,
                ideal: 100,
                max: 120
            )

            TableColumn(
                "デバイス名",
                value: \.deviceName
            )
            .width(
                min: 120,
                ideal: 150,
                max: 190
            )

            TableColumn(
                "プロセス",
                value: \.process
            )
            .width(
                min: 90,
                ideal: 120,
                max: 180
            )

            TableColumn(
                "PID",
                value: \.pid
            )
            .width(
                min: 50,
                ideal: 65,
                max: 80
            )

            TableColumn("メッセージ") { entry in
                Text(entry.message)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .width(
                min: 360,
                ideal: 700,
                max: 1200
            )
        }
        .tableStyle(.inset)
        .alternatingRowBackgrounds()
    }

    private var pageControls: some View {
        HStack(spacing: 12) {
            Button {
                guard currentPage > 0 else {
                    return
                }

                currentPage -= 1
                selectedEntryIDs.removeAll()
            } label: {
                Label(
                    "前へ",
                    systemImage: "chevron.left"
                )
            }
            .disabled(currentPage == 0)

            VStack(spacing: 2) {
                if let totalCount {
                    Text(
                        "\(firstDisplayedNumber.formatted())–\(lastDisplayedNumber.formatted()) / \(totalCount.formatted()) 件"
                    )
                } else {
                    Text(
                        "\(firstDisplayedNumber.formatted())–\(lastDisplayedNumber.formatted()) 件以上"
                    )
                }

                Text(
                    "\(document.fileName) — \(filter.title)"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .monospacedDigit()

            Button {
                guard hasMorePages else {
                    return
                }

                currentPage += 1
                selectedEntryIDs.removeAll()
            } label: {
                Label(
                    "次へ",
                    systemImage: "chevron.right"
                )
            }
            .disabled(!hasMorePages)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            .regularMaterial,
            ignoresSafeAreaEdges: [.bottom]
        )
    }

    private func loadCurrentPage() async {
        guard !Task.isCancelled else {
            return
        }

        countTask?.cancel()
        countTask = nil

        isPreparing = true

        let currentDocument =
            document

        let currentFilter =
            filter

        let currentSearch =
            normalizedSearchText

        let currentPage =
            self.currentPage

        let currentCountKey =
            countKey

        if let cached =
            countCache[currentCountKey] {

            totalCount = cached

        } else {
            totalCount = nil
        }

        let result: LogPageResult

        do {
            result = try await Task.detached(
                priority: .userInitiated
            ) {
                try await LogParser.readPage(
                    url: currentDocument.url,
                    filter: currentFilter,
                    searchText: currentSearch,
                    page: currentPage,
                    pageSize: 2_000
                )
            }.value
        } catch is CancellationError {
            return
        } catch {
            pageEntries = []
            totalCount = 0
            hasMorePages = false
            isPreparing = false
            return
        }

        guard !Task.isCancelled else {
            return
        }

        pageEntries = result.entries
        hasMorePages = result.hasMore
        isPreparing = false

        if pageEntries.isEmpty {
            if totalCount == nil {
                totalCount = 0
                countCache[currentCountKey] = 0
            }

            return
        }

        /*
         最初のページを表示してから、
         正確な件数は後ろで計算する。
         */
        guard countCache[currentCountKey] == nil else {
            return
        }

        countTask = Task { @MainActor in
            do {
                // 表示を先に出す。
                try await Task.sleep(
                    nanoseconds: 350_000_000
                )
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            do {
                let count =
                    try await Task.detached(
                        priority: .utility
                    ) {
                        try await LogParser.countMatches(
                            url: currentDocument.url,
                            filter: currentFilter,
                            searchText: currentSearch
                        )
                    }.value

                guard !Task.isCancelled else {
                    return
                }

                countCache[currentCountKey] =
                    count

                if self.countKey ==
                    currentCountKey {

                    totalCount = count

                    hasMorePages =
                        (
                            currentPage + 1
                        ) * pageSize < count
                }
            } catch {
                // 件数取得失敗は表示そのものを失敗させない。
            }

            countTask = nil
        }
    }
}
