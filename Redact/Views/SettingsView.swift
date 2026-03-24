import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Visibility Rules") {
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
                }

                Section("Training Mode") {
                    Toggle("Enable on first document", isOn: $appState.settings.trainingModeEnabled)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    Text("Write without looking back.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                #if DEBUG
                Section("Debug") {
                    Button("Reset First Document Flag") {
                        appState.settings.hasCompletedFirstDocument = false
                        appState.save()
                    }
                }
                #endif
            }
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
