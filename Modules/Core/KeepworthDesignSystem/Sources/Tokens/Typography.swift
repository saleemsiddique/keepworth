import SwiftUI

/// Two voices, both from the system: SF Mono for money and SF Pro for everything else. No font
/// assets, no licences, no download weight.
///
/// Every one of these is built from a text style rather than a fixed point size, so the whole
/// app follows Dynamic Type without a single extra line at the call site.
extension Font {
    /// The one figure that headlines a screen.
    public static let headlineAmount = system(.largeTitle, design: .monospaced, weight: .semibold)
        .monospacedDigit()

    /// Amounts inside a row. Monospaced so the decimal points line up down the column, which
    /// is what makes a list of figures readable at a glance.
    public static let rowAmount = system(.body, design: .monospaced).monospacedDigit()

    public static let rowTitle = body

    public static let rowSubtitle = footnote

    /// Metadata and section headings: small SF Pro, and uppercase with wide tracking wherever
    /// it is used. `SectionCaption` applies those two, because they never travel apart.
    public static let sectionCaption = caption.weight(.medium)

    public static let primaryAction = body.weight(.semibold)

    /// The add button in the tab bar, the one symbol big enough to need its own size.
    public static let tabBarSymbol = title2
}
