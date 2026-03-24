import SwiftUI

// MARK: - Navigation Destination

enum AppDestination: Hashable {
    case write(UUID)
    case edit(UUID)
}

// MARK: - DocumentListView

struct DocumentListView: View {
    @Environment(\.documentStore) private var store
    @EnvironmentObject private var appState: AppState

    @State private var path: [AppDestination] = []
    @State private var documents: [Document] = []
    @State private var inProgressDocument: Document?
    @State private var pendingNewDocument: Document?

    @State private var showSettings = false
    @State private var showNewDocumentSheet = false
    @State private var showDeleteConfirmation = false
    @State private var documentToDelete: Document?

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Redact")
                .toolbar {
                    leadingToolbarContent
                    trailingToolbarContent
                }
                .navigationDestination(for: AppDestination.self) { destination in
                    switch destination {
                    case .write(let id):
                        if let doc = inProgressDocument, doc.id == id {
                            WriteView(document: doc)
                        } else if let doc = pendingNewDocument, doc.id == id {
                            WriteView(document: doc)
                        }
                    case .edit(let id):
                        EditView(documentID: id)
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
                .sheet(isPresented: $showNewDocumentSheet) {
                    NewDocumentSheet { doc in
                        pendingNewDocument = doc
                        do {
                            try store.saveInProgress(document: doc)
                        } catch {
                            print("Failed to save new document: \(error)")
                        }
                        path.append(.write(doc.id))
                    }
                }
                .alert("Delete Document?", isPresented: $showDeleteConfirmation, presenting: documentToDelete) { doc in
                    Button("Delete", role: .destructive) {
                        do {
                            try store.delete(document: doc)
                            documents.removeAll { $0.id == doc.id }
                        } catch {
                            print("Delete failed: \(error)")
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { doc in
                    Text("'\(doc.title)' will be permanently deleted.")
                }
                .onAppear { refresh() }
                .onChange(of: path) { newPath in
                    if newPath.isEmpty {
                        refresh()
                    }
                }
        }
    }

    // MARK: - Toolbar Items

    @ToolbarContentBuilder
    private var leadingToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
            }
        }
    }

    @ToolbarContentBuilder
    private var trailingToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showNewDocumentSheet = true
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if documents.isEmpty && inProgressDocument == nil {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    if inProgressDocument != nil {
                        inProgressCard
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                    }

                    if !documents.isEmpty {
                        completedList
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Documents Yet")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            Text("Tap + to start writing")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - In-Progress Card

    private var inProgressCard: some View {
        Button {
            if let doc = inProgressDocument {
                path.append(.write(doc.id))
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Continue Writing")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.accentColor)

                Text("\(inProgressDocument?.title ?? "Untitled") · \(inProgressDocument?.rawText.wordCount ?? 0) words")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let target = inProgressDocument?.wordCountTarget {
                    let current = inProgressDocument?.rawText.wordCount ?? 0
                    ProgressView(value: Double(min(current, target)), total: Double(target))
                        .tint(.accentColor)
                    Text("\(current) / \(target)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Completed List

    private var completedList: some View {
        List {
            ForEach(documents) { doc in
                Button {
                    path.append(.edit(doc.id))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(doc.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack(spacing: 8) {
                            Text("\(doc.rawText.wordCount) words")
                            Text("·")
                            Text((doc.revealedAt ?? doc.lastModifiedAt).relativeDisplay)
                            if let stats = doc.stats {
                                Text("·")
                                Text(formatDuration(stats.durationSeconds))
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        documentToDelete = doc
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .frame(minHeight: 200)
    }

    // MARK: - Helpers

    private func refresh() {
        do {
            documents = try store.loadAll()
            inProgressDocument = try store.loadInProgress()
        } catch {
            print("Refresh failed: \(error)")
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return "\(m)m \(s)s"
    }
}
