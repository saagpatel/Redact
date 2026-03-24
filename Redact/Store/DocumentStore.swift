import Foundation

@MainActor
final class DocumentStore {

    private let baseURL: URL
    private let documentsURL: URL
    private let inProgressURL: URL
    private let fileManager = FileManager.default

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Initialize with a custom base URL (for testing) or nil for the default app sandbox.
    init(baseURL: URL? = nil) {
        let base = baseURL ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("redact", isDirectory: true)
        self.baseURL = base
        self.documentsURL = base.appendingPathComponent("documents", isDirectory: true)
        self.inProgressURL = documentsURL.appendingPathComponent("in-progress", isDirectory: true)

        createDirectoryStructure()
    }

    // MARK: - Directory Setup

    private func createDirectoryStructure() {
        try? fileManager.createDirectory(at: inProgressURL, withIntermediateDirectories: true)
    }

    // MARK: - Save

    func save(document: Document) throws {
        let url = documentsURL.appendingPathComponent("\(document.id.uuidString).json")
        try atomicWrite(document, to: url)
    }

    func saveInProgress(document: Document) throws {
        let url = inProgressURL.appendingPathComponent("\(document.id.uuidString).json")
        try atomicWrite(document, to: url)
    }

    // MARK: - Load

    func loadAll() throws -> [Document] {
        guard fileManager.fileExists(atPath: documentsURL.path) else { return [] }

        let contents = try fileManager.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        let documents: [Document] = contents
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Document.self, from: data)
            }

        return documents.sorted { lhs, rhs in
            let lhsDate = lhs.revealedAt ?? lhs.lastModifiedAt
            let rhsDate = rhs.revealedAt ?? rhs.lastModifiedAt
            return lhsDate > rhsDate
        }
    }

    func loadInProgress() throws -> Document? {
        guard fileManager.fileExists(atPath: inProgressURL.path) else { return nil }

        let contents = try fileManager.contentsOfDirectory(
            at: inProgressURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )

        let jsonFiles = contents.filter { $0.pathExtension == "json" }
        guard !jsonFiles.isEmpty else { return nil }

        // Return the most recently modified file
        let sorted = try jsonFiles.sorted { lhs, rhs in
            let lhsDate = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let rhsDate = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return lhsDate > rhsDate
        }

        guard let mostRecent = sorted.first else { return nil }
        let data = try Data(contentsOf: mostRecent)
        return try decoder.decode(Document.self, from: data)
    }

    // MARK: - Delete

    func delete(document: Document) throws {
        let url = documentsURL.appendingPathComponent("\(document.id.uuidString).json")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func deleteInProgress(id: UUID) throws {
        let url = inProgressURL.appendingPathComponent("\(id.uuidString).json")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Atomic Write

    private func atomicWrite(_ document: Document, to destinationURL: URL) throws {
        let data = try encoder.encode(document)
        let tmpURL = destinationURL.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)

        if fileManager.fileExists(atPath: destinationURL.path) {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: tmpURL)
        } else {
            try fileManager.moveItem(at: tmpURL, to: destinationURL)
        }
    }
}
