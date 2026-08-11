import SwiftUI

@main
struct RedactApp: App {
    @StateObject private var appState = AppState()
    private let store = DocumentStore()

    init() {
        Theme.applyNavigationAppearance()
    }

    var body: some Scene {
        WindowGroup {
            DocumentListView()
                .environmentObject(appState)
                .environment(\.documentStore, store)
                .tint(Theme.ink)
        }
    }
}
