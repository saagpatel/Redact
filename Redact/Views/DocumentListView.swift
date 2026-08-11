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
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
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
                .alert("Redact Couldn't Complete That Action", isPresented: errorIsPresented) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage ?? "Unknown error")
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
            .disabled(inProgressDocument != nil)
            .accessibilityHint(
                inProgressDocument == nil
                    ? "Starts a forward-only writing session"
                    : "Finish the current writing session before starting another"
            )
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        Group {
            if documents.isEmpty && inProgressDocument == nil {
                emptyState
            } else {
                List {
                    masthead
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))

                    if inProgressDocument != nil {
                        Section {
                            inProgressCard
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } header: {
                            BarSectionHeader(title: "In Progress")
                        }
                    }

                    if !documents.isEmpty {
                        completedList
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.paper.ignoresSafeArea())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead
                .padding(.horizontal, 20)
                .padding(.top, 8)
            Spacer()
            VStack(spacing: 24) {
                RedactionBarsGlyph()
                VStack(spacing: 8) {
                    Text("Nothing on file")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundColor(Theme.ink)
                    EyebrowText("Tap + to start writing")
                }
            }
            .frame(maxWidth: .infinity)
            Spacer()
        }
    }

    /// The letterhead: serif masthead over a thin ink rule.
    private var masthead: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Redact")
                .font(.system(.largeTitle, design: .serif).weight(.black))
                .foregroundColor(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Rectangle()
                .fill(Theme.ink)
                .frame(height: 3)
        }
    }

    // MARK: - In-Progress Card

    private var inProgressCard: some View {
        Button {
            if let doc = inProgressDocument {
                path.append(.write(doc.id))
            }
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Theme.stamp)
                            .frame(width: 7, height: 7)
                        EyebrowText("Continue Writing", color: Theme.ink)
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Theme.ink)
                        Spacer(minLength: 0)
                    }

                    Text("\(inProgressDocument?.title ?? "Untitled") · \(inProgressDocument?.rawText.wordCount ?? 0) words")
                        .font(Theme.meta)
                        .foregroundColor(Theme.inkSecondary)

                    if let target = inProgressDocument?.wordCountTarget {
                        let current = inProgressDocument?.rawText.wordCount ?? 0
                        targetProgressBar(current: current, target: target)
                        Text("\(current) / \(target)")
                            .font(Theme.meta)
                            .foregroundColor(Theme.inkSecondary)
                    }
                }
                .padding(14)
            }
            .background(Theme.paperRaised)
            .overlay(Rectangle().strokeBorder(Theme.inkFaint, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func targetProgressBar(current: Int, target: Int) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.inkFaint)
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: proxy.size.width * min(1, CGFloat(current) / CGFloat(max(target, 1))))
            }
        }
        .frame(height: 3)
        .accessibilityElement()
        .accessibilityLabel("Progress: \(current) of \(target) words")
    }

    // MARK: - Completed List

    private var completedList: some View {
        Section {
            ForEach(documents) { doc in
                Button {
                    path.append(.edit(doc.id))
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(doc.title)
                            .font(Theme.serifTitle)
                            .foregroundColor(Theme.ink)

                        HStack(spacing: 8) {
                            Text("\(doc.rawText.wordCount) words")
                            Text("·")
                            Text((doc.revealedAt ?? doc.lastModifiedAt).relativeDisplay)
                            if let stats = doc.stats {
                                Text("·")
                                Text(formatDuration(stats.durationSeconds))
                            }
                        }
                        .font(Theme.meta)
                        .foregroundColor(Theme.inkSecondary)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Theme.inkFaint)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        documentToDelete = doc
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            BarSectionHeader(title: "Completed")
        }
    }

    // MARK: - Helpers

    private func refresh() {
        do {
            documents = try store.loadAll()
            inProgressDocument = try store.loadInProgress()
        } catch {
            errorMessage = "Your saved writing could not be read. Redact left the files untouched. \(error.localizedDescription)"
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return "\(m)m \(s)s"
    }
}
