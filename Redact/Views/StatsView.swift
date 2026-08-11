import SwiftUI
import UIKit

struct StatsView: View {
    let stats: WritingStats
    let rawText: String
    let onDismiss: () -> Void
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // The card leads with its own redaction bar.
            Rectangle()
                .fill(Theme.ink)
                .frame(height: 6)

            VStack(spacing: 20) {
                EyebrowText("Session Report", color: Theme.inkSecondary)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 0) {
                    statItem(value: "\(stats.wordCount)", label: "Words")
                        .accessibilityLabel("Word count: \(stats.wordCount)")
                    divider
                    statItem(value: "\(stats.paragraphCount)", label: "Paragraphs")
                        .accessibilityLabel("Paragraph count: \(stats.paragraphCount)")
                    divider
                    statItem(value: formattedDuration, label: "Duration")
                        .accessibilityLabel("Duration: \(accessibleDuration)")
                    divider
                    statItem(value: "\(Int(stats.wordsPerMinute))", label: "WPM")
                        .accessibilityLabel("Words per minute: \(Int(stats.wordsPerMinute))")
                }

                HStack(spacing: 12) {
                    Button("Start Editing") {
                        onDismiss()
                    }
                    .buttonStyle(BarButtonStyle())
                    .accessibilityIdentifier("Start Editing")

                    Button("Share") {
                        showShareSheet = true
                    }
                    .buttonStyle(GhostButtonStyle())
                    .accessibilityIdentifier("Share")
                }
            }
            .padding(20)
        }
        .background(Theme.paperRaised)
        .overlay(Rectangle().strokeBorder(Theme.inkFaint, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: [rawText])
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.inkFaint)
            .frame(width: 1, height: 36)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.numeral)
                .foregroundColor(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            EyebrowText(label, style: .caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedDuration: String {
        let minutes = Int(stats.durationSeconds) / 60
        let seconds = Int(stats.durationSeconds) % 60
        return "\(minutes)m \(seconds)s"
    }

    private var accessibleDuration: String {
        let minutes = Int(stats.durationSeconds) / 60
        let seconds = Int(stats.durationSeconds) % 60
        if minutes == 0 {
            return "\(seconds) seconds"
        } else if seconds == 0 {
            return "\(minutes) minutes"
        } else {
            return "\(minutes) minutes \(seconds) seconds"
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
