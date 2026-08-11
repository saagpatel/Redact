import SwiftUI
import UIKit

// MARK: - Ink & Paper (UIKit level)

/// Redact's design language: paper and ink.
///
/// The visual world is the censor's office: warm paper, near-black ink, the
/// redaction bar as a structural element, and one archival stamp red reserved
/// for live-session and destructive signals. Every custom color is dynamic
/// (light + dark) and defined here — nowhere else in the app.
///
/// Colors live at the UIKit level so the redaction engine (CAShapeLayer fills,
/// UITextView ink) and the SwiftUI chrome share the exact same ink.
extension UIColor {
    /// Near-black ink in light mode, warm bone in dark. Text, bars, chrome.
    static let redactInk = UIColor(
        light: UIColor(red: 0.086, green: 0.078, blue: 0.059, alpha: 1),
        dark: UIColor(red: 0.918, green: 0.906, blue: 0.875, alpha: 1)
    )

    /// Warm paper — the app background.
    static let redactPaper = UIColor(
        light: UIColor(red: 0.969, green: 0.961, blue: 0.941, alpha: 1),
        dark: UIColor(red: 0.090, green: 0.086, blue: 0.075, alpha: 1)
    )

    /// Raised paper — cards, sheets, floating chrome.
    static let redactPaperRaised = UIColor(
        light: UIColor(red: 0.992, green: 0.988, blue: 0.976, alpha: 1),
        dark: UIColor(red: 0.125, green: 0.118, blue: 0.102, alpha: 1)
    )

    fileprivate convenience init(light: UIColor, dark: UIColor) {
        self.init { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }
}

// MARK: - Theme

enum Theme {
    // MARK: Colors

    static let ink = Color(UIColor.redactInk)
    static let paper = Color(UIColor.redactPaper)
    static let paperRaised = Color(UIColor.redactPaperRaised)

    /// Secondary ink — metadata, captions, quiet labels.
    static let inkSecondary = Color(UIColor(
        light: UIColor(red: 0.431, green: 0.416, blue: 0.376, alpha: 1),
        dark: UIColor(red: 0.659, green: 0.639, blue: 0.600, alpha: 1)
    ))

    /// Faint ink — hairline rules and borders.
    static let inkFaint = Color(UIColor(
        light: UIColor(red: 0.867, green: 0.851, blue: 0.808, alpha: 1),
        dark: UIColor(red: 0.227, green: 0.220, blue: 0.196, alpha: 1)
    ))

    /// Archival stamp red — live-session and destructive signals only.
    static let stamp = Color(UIColor(
        light: UIColor(red: 0.651, green: 0.149, blue: 0.122, alpha: 1),
        dark: UIColor(red: 0.839, green: 0.271, blue: 0.255, alpha: 1)
    ))

    // MARK: Type

    /// Mono caps label — the "stamped" register. Pair with uppercase + tracking
    /// via `EyebrowText`, or apply both at the call site.
    static func eyebrow(_ style: Font.TextStyle = .caption) -> Font {
        .system(style, design: .monospaced).weight(.semibold)
    }

    /// Serif document titles — echoes the New York writing surface.
    static let serifTitle = Font.system(.headline, design: .serif)

    /// Mono metadata — word counts, durations, datelines.
    static let meta = Font.system(.caption, design: .monospaced)

    /// Mono report numerals — the session report card.
    static let numeral = Font.system(.title2, design: .monospaced).weight(.bold)

    // MARK: Navigation appearance

    /// Serif navigation titles on paper. Call once at app launch.
    static func applyNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .redactPaper
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .font: serifUIFont(style: .headline, weight: .semibold),
            .foregroundColor: UIColor.redactInk,
        ]
        appearance.largeTitleTextAttributes = [
            .font: serifUIFont(style: .largeTitle, weight: .black),
            .foregroundColor: UIColor.redactInk,
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    private static func serifUIFont(style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        let weighted = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
        guard let descriptor = weighted.fontDescriptor.withDesign(.serif) else { return weighted }
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }
}

// MARK: - EyebrowText

/// A stamped mono-caps label.
struct EyebrowText: View {
    let text: String
    var color: Color = Theme.inkSecondary
    var style: Font.TextStyle = .caption

    init(_ text: String, color: Color = Theme.inkSecondary, style: Font.TextStyle = .caption) {
        self.text = text
        self.color = color
        self.style = style
    }

    var body: some View {
        Text(text)
            .font(Theme.eyebrow(style))
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundColor(color)
    }
}

// MARK: - BarSectionHeader

/// A short ink bar and a stamped label — the section register of the library.
struct BarSectionHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Theme.ink)
                .frame(width: 18, height: 8)
            EyebrowText(title)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - RedactionBarsGlyph

/// A redacted paragraph in miniature — the empty-state mark.
struct RedactionBarsGlyph: View {
    private let widths: [CGFloat] = [116, 88, 104, 56]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(widths, id: \.self) { width in
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: width, height: 10)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Button Styles

/// Primary action — a full-measure redaction bar.
struct BarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.eyebrow(.footnote))
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundColor(Theme.paper)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.ink.opacity(configuration.isPressed ? 0.75 : 1))
            .contentShape(Rectangle())
    }
}

/// Secondary action — a hairline frame on paper.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.eyebrow(.footnote))
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundColor(Theme.ink)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(configuration.isPressed ? Theme.ink.opacity(0.08) : Color.clear)
            .overlay(Rectangle().strokeBorder(Theme.inkFaint, lineWidth: 1))
            .contentShape(Rectangle())
    }
}
