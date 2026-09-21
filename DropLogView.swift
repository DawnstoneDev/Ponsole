import SwiftUI

@MainActor
struct DropLogView: View {
    let onImport: ([URL]) -> Void

    var body: some View {
        ContentUnavailableView {
            Label(
                "ログを読み込む",
                systemImage: "arrow.down.doc"
            )
        } description: {
            Text(
                "Finderからログファイルをこのウインドウへドラッグ＆ドロップしてください。"
            )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
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

            onImport(files)
        }
    }
}
