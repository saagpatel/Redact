import SwiftUI
import UIKit

struct StatsView: View {
    let stats: WritingStats
    let rawText: String
    let onDismiss: () -> Void
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Writing Complete")
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: 24) {
                statItem(value: "\(stats.wordCount)", label: "Words")
                    .accessibilityLabel("Word count: \(stats.wordCount)")
                statItem(value: "\(stats.paragraphCount)", label: "Paragraphs")
                    .accessibilityLabel("Paragraph count: \(stats.paragraphCount)")
                statItem(value: formattedDuration, label: "Duration")
                    .accessibilityLabel("Duration: \(accessibleDuration)")
                statItem(value: "\(Int(stats.wordsPerMinute))", label: "WPM")
                    .accessibilityLabel("Words per minute: \(Int(stats.wordsPerMinute))")
            }

            HStack(spacing: 16) {
                Button("Start Editing") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)

                Button("Share") {
                    showShareSheet = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: [rawText])
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
