import Foundation
import Combine

@MainActor
final class LogLibrary: ObservableObject {
    @Published private(set) var documents: [LogDocument] = []

    @Published var lastErrorMessage: String?

    func importFiles(
        from urls: [URL]
    ) -> [UUID] {
        var addedIDs: [UUID] = []

        for url in urls {
            guard url.isFileURL,
                  !url.hasDirectoryPath else {
                continue
            }

            let standardizedURL =
                url.standardizedFileURL

            guard !documents.contains(
                where: {
                    $0.url.standardizedFileURL ==
                        standardizedURL
                }
            ) else {
                continue
            }

            guard FileManager.default.fileExists(
                atPath: url.path
            ) else {
                continue
            }

            let document = LogDocument(
                url: url
            )

            documents.append(document)
            addedIDs.append(document.id)
        }

        return addedIDs
    }

    func removeAll() {
        documents.removeAll()
        lastErrorMessage = nil
    }
}
