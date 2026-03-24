import SwiftUI

struct AppSettings: Codable, Equatable {
    var visibilityFullParagraphs: Int = 1        // paragraphs shown at 100%
    var visibilityPartialParagraphs: Int = 1     // paragraphs shown at ~50%
    var hasCompletedFirstDocument: Bool = false
    var trainingModeEnabled: Bool = true
}

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings

    private let fileURL: URL
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseURL: URL? = nil) {
        let base = baseURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("redact", isDirectory: true)
        self.fileURL = base.appendingPathComponent("settings.json")
        self.settings = AppSettings()

        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        load()
    }

    func save() {
        do {
            let data = try encoder.encode(settings)
            let tmpURL = fileURL.appendingPathExtension("tmp")
            try data.write(to: tmpURL, options: .atomic)

            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try fileManager.replaceItemAt(fileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: fileURL)
            }
        } catch {
            print("AppState.save failed: \(error)")
        }
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            settings = try decoder.decode(AppSettings.self, from: data)
        } catch {
            print("AppState.load failed: \(error)")
        }
    }
}

// MARK: - Environment Key for DocumentStore

private struct DocumentStoreKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = DocumentStore()
}

extension EnvironmentValues {
    var documentStore: DocumentStore {
        get { self[DocumentStoreKey.self] }
        set { self[DocumentStoreKey.self] = newValue }
    }
}
