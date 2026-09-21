import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ContentView: View {
    @StateObject private var library =
        LogLibrary()

    @State private var selection:
        SidebarSelection?

    @State private var activeDocumentID:
        LogDocument.ID?

    @State private var filtersByDocument:
        [LogDocument.ID: LogFilter] = [:]

    @State private var searchText = ""

    @State private var selectedEntryIDs:
        Set<LogEntry.ID> = []

    @State private var isImporterPresented =
        false

    private let allowedLogTypes: [UTType] = [
        .plainText,
        .data
    ]

    private var activeDocument:
        LogDocument? {

        guard let activeDocumentID else {
            return nil
        }

        return library.documents.first {
            $0.id == activeDocumentID
        }
    }

    private var activeFilter:
        LogFilter {

        guard let activeDocumentID else {
            return .all
        }

        return filtersByDocument[
            activeDocumentID
        ] ?? .all
    }

    private var searchPrompt: String {
        guard let activeDocument else {
            return "ログを検索"
        }

        return "\(activeDocument.fileName)を検索"
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                library: library,
                selection: $selection,
                activeDocumentID:
                    activeDocumentID,
                activeFilter:
                    activeFilter
            )
        } detail: {
            detailView
        }
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: searchPrompt
        )
        .toolbar {
            ToolbarItem {
                Button(
                    "ログを追加…",
                    systemImage: "plus"
                ) {
                    isImporterPresented =
                        true
                }
                .keyboardShortcut(
                    "o",
                    modifiers: [.command]
                )
                .help("ログファイルを追加")
            }
        }
        .fileImporter(
            isPresented:
                $isImporterPresented,
            allowedContentTypes:
                allowedLogTypes,
            allowsMultipleSelection:
                true
        ) { result in

            switch result {
            case .success(let urls):
                importFiles(urls)

            case .failure(let error):
                library.lastErrorMessage =
                    error.localizedDescription
            }
        }
        .alert(
            "ログを読み込めませんでした",
            isPresented: Binding(
                get: {
                    library.lastErrorMessage != nil
                },
                set: { presented in
                    if !presented {
                        library.lastErrorMessage =
                            nil
                    }
                }
            )
        ) {
            Button("OK") {
                library.lastErrorMessage =
                    nil
            }
        } message: {
            Text(
                library.lastErrorMessage ?? ""
            )
        }
        .onChange(of: selection) {
            _, newSelection in

            switch newSelection {
            case .log(let id):
                activeDocumentID = id
                searchText = ""
                selectedEntryIDs.removeAll()

            case .filter(let filter):
                guard let activeDocumentID else {
                    return
                }

                filtersByDocument[
                    activeDocumentID
                ] = filter

                selectedEntryIDs.removeAll()

            case nil:
                break
            }
        }
        .onChange(
            of: library.documents.count
        ) {
            _, newCount in

            if newCount == 0 {
                activeDocumentID = nil
                selection = nil
                filtersByDocument.removeAll()
                selectedEntryIDs.removeAll()
                searchText = ""
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let document =
            activeDocument {

            LogTableView(
                document: document,
                filter: activeFilter,
                searchText: searchText,
                selectedEntryIDs:
                    $selectedEntryIDs
            )
            .dropDestination(
                for: URL.self,
                isEnabled: true
            ) { urls, _ in

                let files = urls.filter {
                    $0.isFileURL &&
                    !$0.hasDirectoryPath
                }

                guard !files.isEmpty else {
                    return
                }

                importFiles(files)
            }
        } else {
            DropLogView(
                onImport:
                    importFiles
            )
        }
    }

    private func importFiles(
        _ urls: [URL]
    ) {
        let addedIDs =
            library.importFiles(
                from: urls
            )

        guard activeDocumentID == nil,
              let firstID =
                addedIDs.first else {
            return
        }

        activeDocumentID =
            firstID

        selection =
            .log(firstID)

        searchText = ""
        selectedEntryIDs.removeAll()
    }
}
