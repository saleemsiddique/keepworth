import SwiftUI

/// The six semantic colours, and the only ones the app is allowed to paint with.
///
/// They resolve from `Tokens.xcassets`, so each one carries its light and its dark variant and
/// the system swaps them. A literal colour or a system colour anywhere outside this file is a
/// bug: it will look wrong in one of the two themes, and nobody will notice until it ships.
///
/// Declared on `ShapeStyle` so they read as SwiftUI's own: `.foregroundStyle(.ink)`,
/// `.background(.bg)`. `Color.ink` works too.
extension ShapeStyle where Self == Color {
    /// The page. Pure black in dark, which is free contrast on OLED.
    public static var bg: Color { token("bg") }

    /// Sheets, and only sheets. Using it as a card background would bring back the boxes the
    /// design does without.
    public static var surface: Color { token("surface") }

    /// Text, and every amount that is not incoming. **Expenses use this, never red**: the app
    /// does not tell the user off for spending.
    public static var ink: Color { token("ink") }

    /// Secondary text, captions and metadata.
    public static var inkSoft: Color { token("inkSoft") }

    /// Separators, drawn at 0.5 pt. See `Hairline`.
    public static var hairline: Color { token("hairline") }

    /// Phosphor green. Interactive elements and money coming **in**. Nothing else.
    public static var accent: Color { token("accent") }

    private static func token(_ name: String) -> Color {
        Color(name, bundle: .module)
    }
}
