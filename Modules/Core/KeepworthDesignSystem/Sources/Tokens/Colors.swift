import SwiftUI

/// The seven semantic colours, and the only ones the app is allowed to paint with.
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

    /// Text, and any amount that neither comes in nor goes out — a positive balance, a figure
    /// that is only a total.
    public static var ink: Color { token("ink") }

    /// Secondary text, captions and metadata.
    public static var inkSoft: Color { token("inkSoft") }

    /// Separators, drawn at 0.5 pt. See `Hairline`.
    public static var hairline: Color { token("hairline") }

    /// Phosphor green. Interactive elements and money coming **in**. Nothing else.
    public static var accent: Color { token("accent") }

    /// Money going **out**: expenses, negative balances, the spending total of a period.
    ///
    /// Built to mirror `accent` rather than to alarm — deep and desaturated in light, bright in
    /// dark, the same way the green is. It marks direction, not blame.
    public static var expense: Color { token("expense") }

    private static func token(_ name: String) -> Color {
        Color(name, bundle: .module)
    }
}
