import SwiftUI

struct NewDocumentSheet: View {
    let onStart: (Document) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var wordCountTargetText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Untitled", text: $title)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Title")
                }

                Section {
                    TextField("No target — write until done", text: $wordCountTargetText)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Word Count Target")
                }
            }
            .navigationTitle("New Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Writing") {
                        let target = Int(wordCountTargetText)
                        let document = Document(
                            id: UUID(),
                            title: title.isEmpty ? "Untitled" : title,
                            rawText: "",
                            redactionState: RedactionState(paragraphs: [], activeParagraphIndex: 0),
                            isComplete: false,
                            wordCountTarget: target,
                            createdAt: Date(),
                            lastModifiedAt: Date(),
                            revealedAt: nil,
                            stats: nil
                        )
                        onStart(document)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
