import SwiftUI

@MainActor
struct SidebarView: View {
    @ObservedObject var library: LogLibrary

    @Binding var selection:
        SidebarSelection?

    let activeDocumentID:
        LogDocument.ID?

    let activeFilter:
        LogFilter

    var body: some View {
        List(selection: $selection) {
            Section("ログ") {
                if library.documents.isEmpty {
                    Label(
                        "ログはありません",
                        systemImage: "doc.text"
                    )
                    .foregroundStyle(.secondary)
                } else {
                    ForEach(
                        library.documents
                    ) { document in
                        logRow(
                            for: document
                        )
                    }
                }
            }

            Section {
                ForEach(
                    LogFilter.allCases,
                    id: \.self
                ) { filter in
                    filterRow(
                        for: filter
                    )
                }
            } header: {
                Text(
                    filterSectionTitle
                )
            }

            Section {
                Button(
                    "ログをすべて消去",
                    systemImage: "trash",
                    role: .destructive
                ) {
                    selection = nil
                    library.removeAll()
                }
                .disabled(
                    library.documents.isEmpty
                )
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Ponsole")
        .navigationSplitViewColumnWidth(
            min: 220,
            ideal: 270,
            max: 360
        )
    }

    private var filterSectionTitle:
        String {

        guard let activeDocumentID else {
            return "フィルター"
        }

        guard let document =
                library.documents.first(
                    where: {
                        $0.id ==
                            activeDocumentID
                    }
                ) else {
            return "フィルター"
        }

        return "フィルター — \(document.fileName)"
    }

    private func logRow(
        for document: LogDocument
    ) -> some View {
        HStack(spacing: 8) {
            Label(
                document.fileName,
                systemImage: "doc.text"
            )
            .lineLimit(1)
            .truncationMode(.middle)

            Spacer(minLength: 8)

            if activeDocumentID ==
                document.id {

                Image(systemName: "checkmark")
                    .font(
                        .caption.weight(
                            .semibold
                        )
                    )
                    .foregroundStyle(
                        selection ==
                            .log(document.id)
                            ? .white
                            : .primary
                    )
                    .accessibilityLabel(
                        "現在表示中"
                    )
            }
        }
        .tag(
            SidebarSelection.log(
                document.id
            )
        )
        .help(
            document.fileName
        )
    }

    private func filterRow(
        for filter: LogFilter
    ) -> some View {
        HStack(spacing: 8) {
            Label(
                filter.title,
                systemImage:
                    filter.systemImage
            )

            Spacer()

            if activeFilter == filter {
                Image(
                    systemName: "checkmark"
                )
                .font(
                    .caption.weight(
                        .semibold
                    )
                )
                .foregroundStyle(
                    selection ==
                        .filter(filter)
                        ? .white
                        : .primary
                )
                .accessibilityLabel(
                    "\(filter.title)を選択中"
                )
            }
        }
        .tag(
            SidebarSelection.filter(
                filter
            )
        )
        .disabled(
            activeDocumentID == nil
        )
    }
}
