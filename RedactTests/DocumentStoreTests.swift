import XCTest
@testable import Redact

@MainActor
final class DocumentStoreTests: XCTestCase {

    private var tempDir: URL!
    private var store: DocumentStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RedactTests-\(UUID().uuidString)", isDirectory: true)
        store = DocumentStore(baseURL: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeDocument(
        id: UUID = UUID(),
        title: String = "Test Document",
        rawText: String = "Hello world. This is a test document.",
        isComplete: Bool = true,
        revealedAt: Date? = Date(),
        stats: WritingStats? = nil
    ) -> Document {
        Document(
            id: id,
            title: title,
            rawText: rawText,
            redactionState: RedactionState(
                paragraphs: [
                    .init(index: 0, visibility: .visible, partiallyVisibleIndices: [])
                ],
                activeParagraphIndex: 0
            ),
            isComplete: isComplete,
            wordCountTarget: nil,
            createdAt: Date(),
            lastModifiedAt: Date(),
            revealedAt: revealedAt,
            stats: stats
        )
    }

    // MARK: - Save and Load

    func testSaveAndLoadReturnsIdenticalDocument() throws {
        let doc = makeDocument()
        try store.save(document: doc)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, doc.id)
        XCTAssertEqual(loaded[0].title, doc.title)
        XCTAssertEqual(loaded[0].rawText, doc.rawText)
        XCTAssertEqual(loaded[0].isComplete, doc.isComplete)
        XCTAssertEqual(loaded[0].redactionState, doc.redactionState)
    }

    func testSaveInProgressAndLoadReturnsDocument() throws {
        let doc = makeDocument(isComplete: false, revealedAt: nil)
        try store.saveInProgress(document: doc)

        let loaded = try store.loadInProgress()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, doc.id)
        XCTAssertEqual(loaded?.rawText, doc.rawText)
        XCTAssertEqual(loaded?.isComplete, false)
    }

    func testLoadAllReturnsSortedByRevealedAtDescending() throws {
        let now = Date()
        let doc1 = makeDocument(title: "Oldest", revealedAt: now.addingTimeInterval(-200))
        let doc2 = makeDocument(title: "Middle", revealedAt: now.addingTimeInterval(-100))
        let doc3 = makeDocument(title: "Newest", revealedAt: now)

        // Save in scrambled order
        try store.save(document: doc2)
        try store.save(document: doc1)
        try store.save(document: doc3)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].title, "Newest")
        XCTAssertEqual(loaded[1].title, "Middle")
        XCTAssertEqual(loaded[2].title, "Oldest")
    }

    // MARK: - Delete

    func testDeleteRemovesDocument() throws {
        let doc = makeDocument()
        try store.save(document: doc)

        XCTAssertEqual(try store.loadAll().count, 1)

        try store.delete(document: doc)
        XCTAssertEqual(try store.loadAll().count, 0)
    }

    func testDeleteInProgressRemovesFile() throws {
        let doc = makeDocument(isComplete: false, revealedAt: nil)
        try store.saveInProgress(document: doc)

        XCTAssertNotNil(try store.loadInProgress())

        try store.deleteInProgress(id: doc.id)
        XCTAssertNil(try store.loadInProgress())
    }

    // MARK: - Overwrite

    func testSaveOverwriteReturnsLatestVersion() throws {
        var doc = makeDocument()
        try store.save(document: doc)

        doc.title = "Updated Title"
        doc.rawText = "Updated text content."
        try store.save(document: doc)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Updated Title")
        XCTAssertEqual(loaded[0].rawText, "Updated text content.")
    }

    // MARK: - Empty state

    func testLoadInProgressWithNoFilesReturnsNil() throws {
        let result = try store.loadInProgress()
        XCTAssertNil(result)
    }

    func testLoadAllWithNoFilesReturnsEmptyArray() throws {
        let result = try store.loadAll()
        XCTAssertTrue(result.isEmpty)
    }

    func testLoadAllReportsCorruptDocumentInsteadOfSilentlyDroppingIt() throws {
        let documentsDirectory = tempDir.appendingPathComponent("documents", isDirectory: true)
        try Data("not-json".utf8).write(
            to: documentsDirectory.appendingPathComponent("corrupt.json")
        )

        XCTAssertThrowsError(try store.loadAll())
    }

    // MARK: - Session restore simulation

    func testSessionRestoreSimulation() throws {
        // Simulate writing a document, then "force-quitting" and restoring
        let doc = makeDocument(
            title: "In Progress",
            rawText: "First paragraph.\nSecond paragraph.\nThird in progress...",
            isComplete: false,
            revealedAt: nil
        )

        try store.saveInProgress(document: doc)

        // "Relaunch" — new store instance, same directory
        let restoredStore = DocumentStore(baseURL: tempDir)
        let restored = try restoredStore.loadInProgress()

        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.id, doc.id)
        XCTAssertEqual(restored?.rawText, doc.rawText)
        XCTAssertEqual(restored?.redactionState.activeParagraphIndex, doc.redactionState.activeParagraphIndex)
    }

    // MARK: - Stats round-trip

    func testDocumentWithStatsRoundTrips() throws {
        let stats = WritingStats(
            wordCount: 247,
            paragraphCount: 5,
            durationSeconds: 872,
            wordsPerMinute: 17.0,
            longestStreakSeconds: 340
        )
        let doc = makeDocument(stats: stats)
        try store.save(document: doc)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded[0].stats, stats)
    }
}
