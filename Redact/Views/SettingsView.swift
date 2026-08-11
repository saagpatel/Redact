import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        "Fully visible: \(appState.settings.visibilityFullParagraphs)",
                        value: $appState.settings.visibilityFullParagraphs,
                        in: 1...5
                    )
                    Stepper(
                        "Partially visible: \(appState.settings.visibilityPartialParagraphs)",
                        value: $appState.settings.visibilityPartialParagraphs,
                        in: 0...3
                    )
                } header: {
                    EyebrowText("Visibility Rules")
                }

                Section {
                    Toggle("Enable on first document", isOn: $appState.settings.trainingModeEnabled)
                } header: {
                    EyebrowText("Training Mode")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(Theme.inkSecondary)
                    }
                    Text("Write without looking back.")
                        .font(.system(.footnote, design: .serif).italic())
                        .foregroundColor(Theme.inkSecondary)
                } header: {
                    EyebrowText("About")
                }

                #if DEBUG
                Section {
                    Button("Reset First Document Flag") {
                        appState.settings.hasCompletedFirstDocument = false
                        appState.save()
                    }
                } header: {
                    EyebrowText("Debug")
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: appState.settings) { _ in
                appState.save()
            }
        }
    }
}
