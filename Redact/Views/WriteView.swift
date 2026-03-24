import SwiftUI

enum WritePhase {
    case writing
    case revealing
    case stats
}

struct WriteView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.documentStore) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    @State private var document: Document
    @State private var phase: WritePhase = .writing
    @State private var showDoneTooltip = false
    @State private var showTrainingBanner = false
    @State private var shouldReveal = false
    @State private var computedStats: WritingStats?
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var tooltipDismissTask: Task<Void, Never>?
    @State private var trainingBannerDismissTask: Task<Void, Never>?
    @StateObject private var sessionTracker = WritingSessionTracker()

    init(document: Document) {
        _document = State(initialValue: document)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Writing surface
            writingSurface

            // Training banner
            if showTrainingBanner {
                trainingBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }

            // Stats overlay
            if phase == .stats, let stats = computedStats {
                StatsView(
                    stats: stats,
                    rawText: document.rawText,
                    onDismiss: handleStatsDismiss
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .onAppear(perform: handleOnAppear)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background || newPhase == .inactive {
                performImmediateSave()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showTrainingBanner)
        .animation(.easeInOut(duration: 0.4), value: phase)
    }

    // MARK: - Writing Surface

    @ViewBuilder
    private var writingSurface: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                RedactTextView(
                    text: Binding(
                        get: { document.rawText },
                        set: { newText in
                            document.rawText = newText
                            document.lastModifiedAt = Date()
                            autoTitleIfNeeded(from: newText)
                        }
                    ),
                    redactionState: Binding(
                        get: { document.redactionState },
                        set: { document.redactionState = $0 }
                    ),
                    shouldReveal: $shouldReveal,
                    documentID: document.id,
                    visibilityFullParagraphs: effectiveVisibilityFull,
                    visibilityPartialParagraphs: effectiveVisibilityPartial,
                    isEditable: phase == .writing,
                    onTextChange: handleTextChange,
                    onRevealComplete: handleRevealComplete
                )
                .frame(minHeight: 400)
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()

            wordCountLabel

            Spacer()

            if wordCount >= 50 && phase == .writing {
                doneButton
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private var wordCountLabel: some View {
        Group {
            if let target = document.wordCountTarget {
                Text("\(wordCount) / \(target)")
                    .foregroundColor(wordCount >= target ? .green : .secondary)
            } else {
                Text("\(wordCount) words")
                    .foregroundColor(.secondary)
            }
        }
        .font(.subheadline.monospacedDigit())
    }

    private var doneButton: some View {
        Text("Done")
            .font(.body.weight(.semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Done")
            .accessibilityHint("Hold to reveal your document")
            .onLongPressGesture(minimumDuration: 0.8, perform: {
                triggerReveal()
            }, onPressingChanged: { pressing in
                if !pressing && phase == .writing && !shouldReveal {
                    showDoneTooltip = true
                    tooltipDismissTask?.cancel()
                    tooltipDismissTask = Task {
                        try? await Task.sleep(for: .seconds(2))
                        if !Task.isCancelled {
                            showDoneTooltip = false
                        }
                    }
                }
            })
            .overlay(alignment: .bottom) {
                if showDoneTooltip {
                    Text("Hold to reveal")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
                        .offset(y: 28)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: showDoneTooltip)
                }
            }
    }

    // MARK: - Training Banner

    private var trainingBanner: some View {
        Text("Training mode — you can see more of your writing. Dismisses after your first reveal.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }

    // MARK: - Computed Properties

    private var wordCount: Int {
        document.rawText.wordCount
    }

    private var effectiveVisibilityFull: Int {
        if !appState.settings.hasCompletedFirstDocument && appState.settings.trainingModeEnabled {
            return 4
        }
        return appState.settings.visibilityFullParagraphs
    }

    private var effectiveVisibilityPartial: Int {
        if !appState.settings.hasCompletedFirstDocument && appState.settings.trainingModeEnabled {
            return 2
        }
        return appState.settings.visibilityPartialParagraphs
    }

    // MARK: - Handlers

    private func handleOnAppear() {
        if !appState.settings.hasCompletedFirstDocument && appState.settings.trainingModeEnabled {
            showTrainingBanner = true
            trainingBannerDismissTask = Task {
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled {
                    showTrainingBanner = false
                }
            }
        }
    }

    private func handleTextChange() {
        sessionTracker.recordKeystroke()

        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            do {
                try store.saveInProgress(document: document)
            } catch {
                print("Auto-save failed: \(error)")
            }
        }
    }

    private func autoTitleIfNeeded(from text: String) {
        guard document.title == "Untitled" || document.title.isEmpty else { return }
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let titleWords = Array(words.prefix(5))
        if !titleWords.isEmpty {
            document.title = titleWords.joined(separator: " ")
        }
    }

    private func triggerReveal() {
        phase = .revealing
        shouldReveal = true
    }

    private func handleRevealComplete() {
        let wc = document.rawText.wordCount
        let paragraphs = document.rawText.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let pc = paragraphs.count

        computedStats = sessionTracker.computeStats(wordCount: wc, paragraphCount: pc)

        document.isComplete = true
        document.revealedAt = Date()
        document.stats = computedStats

        do {
            try store.save(document: document)
            try store.deleteInProgress(id: document.id)
        } catch {
            print("Failed to save completed document: \(error)")
        }

        if !appState.settings.hasCompletedFirstDocument {
            appState.settings.hasCompletedFirstDocument = true
            appState.save()
        }

        showTrainingBanner = false
        trainingBannerDismissTask?.cancel()
        phase = .stats
    }

    private func handleStatsDismiss() {
        dismiss()
    }

    private func performImmediateSave() {
        autoSaveTask?.cancel()
        guard !document.isComplete else { return }
        do {
            try store.saveInProgress(document: document)
        } catch {
            print("Immediate save failed: \(error)")
        }
    }
}
