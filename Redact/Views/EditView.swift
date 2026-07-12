import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct EditView: View {
    let documentID: UUID

    @Environment(\.documentStore) private var store
    @Environment(\.scenePhase) private var scenePhase

    @State private var document: Document?
    @State private var showExportOptions = false
    @State private var showShareSheet = false
    @State private var showDocumentPicker = false
    @State private var exportFileURL: URL?
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var copyConfirmation = false
    @State private var exportErrorMessage: String?

    var body: some View {
        Group {
            if let doc = document {
                editorContent(for: doc)
                    .navigationTitle(doc.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Export") { showExportOptions = true }
                        }
                    }
                    .confirmationDialog("Export", isPresented: $showExportOptions) {
                        Button("Copy Text") { copyText() }
                        Button("Save as .txt") { exportAsTxt() }
                        Button("Save as .md") { exportAsMarkdown() }
                        Button("Share") { showShareSheet = true }
                        Button("Cancel", role: .cancel) {}
                    }
                    .sheet(isPresented: $showShareSheet) {
                        ActivityViewController(activityItems: [document?.rawText ?? ""])
                    }
                    .sheet(isPresented: $showDocumentPicker) {
                        if let url = exportFileURL {
                            DocumentExportPicker(fileURL: url)
                        }
                    }
                    .alert("Copied", isPresented: $copyConfirmation) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("The document text is on the clipboard.")
                    }
                    .alert("Export Failed", isPresented: exportErrorIsPresented) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(exportErrorMessage ?? "Unknown error")
                    }
                    .onChange(of: scenePhase) { newPhase in
                        if newPhase == .background || newPhase == .inactive {
                            performImmediateSave()
                        }
                    }
            } else {
                ProgressView()
                    .onAppear { loadDocument() }
            }
        }
    }

    // MARK: - Editor Content

    @ViewBuilder
    private func editorContent(for doc: Document) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Title", text: titleBinding)
                    .font(.title2.weight(.bold))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                TextEditor(text: rawTextBinding)
                    .font(.custom("Georgia", size: 18))
                    .frame(minHeight: 400)
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Bindings

    private var titleBinding: Binding<String> {
        Binding(
            get: { document?.title ?? "" },
            set: { newValue in
                document?.title = newValue
                scheduleAutoSave()
            }
        )
    }

    private var rawTextBinding: Binding<String> {
        Binding(
            get: { document?.rawText ?? "" },
            set: { newValue in
                document?.rawText = newValue
                document?.lastModifiedAt = Date()
                scheduleAutoSave()
            }
        )
    }

    // MARK: - Load

    private func loadDocument() {
        do {
            let all = try store.loadAll()
            document = all.first { $0.id == documentID }
        } catch {
            print("EditView load failed: \(error)")
        }
    }

    // MARK: - Auto-Save

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let doc = document else { return }
            do {
                try store.save(document: doc)
            } catch {
                print("Auto-save failed: \(error)")
            }
        }
    }

    private func performImmediateSave() {
        autoSaveTask?.cancel()
        guard let doc = document else { return }
        do {
            try store.save(document: doc)
        } catch {
            print("Immediate save failed: \(error)")
        }
    }

    // MARK: - Export

    private func copyText() {
        UIPasteboard.general.string = document?.rawText ?? ""
        copyConfirmation = true
    }

    private func exportAsTxt() {
        guard let doc = document else { return }
        let filename = "\(safeFilename(for: doc.title)).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try doc.rawText.write(to: tempURL, atomically: true, encoding: .utf8)
            exportFileURL = tempURL
            showDocumentPicker = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func exportAsMarkdown() {
        guard let doc = document else { return }
        let filename = "\(safeFilename(for: doc.title)).md"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.string(from: doc.revealedAt ?? doc.createdAt)
        let wpm = doc.stats.map { Int($0.wordsPerMinute) } ?? 0

        let content = """
        ---
        title: "\(doc.title.replacingOccurrences(of: "\"", with: "\\\""))"
        date: \(date)
        wordCount: \(doc.rawText.wordCount)
        wpm: \(wpm)
        ---
        \(doc.rawText)
        """

        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            exportFileURL = tempURL
            showDocumentPicker = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func safeFilename(for title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let sanitized = title.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String((sanitized.isEmpty ? "Redact Export" : sanitized).prefix(80))
    }

    private var exportErrorIsPresented: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )
    }
}

// MARK: - DocumentExportPicker

struct DocumentExportPicker: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL])
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
