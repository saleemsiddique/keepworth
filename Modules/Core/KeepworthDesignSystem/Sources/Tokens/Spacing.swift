import CoreGraphics

/// Hierarchy in this app is built from white space and 0.5 pt rules, not from cards and
/// shadows. That makes these numbers the layout mechanism, so they get one authoritative home.
///
/// Named for what they separate rather than as a t-shirt scale: every value here is one a
/// component actually uses today. When a screen in a later phase needs a gap that is not on
/// this list, it gets added with a name, not approximated with the nearest one.
public enum Spacing {
    /// Between two lines that belong to the same thought, such as a row title and its subtitle.
    public static let withinLine: CGFloat = 2

    /// Between the parts of one component, such as a caption and the figure it labels.
    public static let withinBlock: CGFloat = 6

    /// The vertical breathing room of a single row.
    public static let row: CGFloat = 12

    /// The left and right edge of every screen.
    public static let screenMargin: CGFloat = 20

    /// Between one section of a screen and the next. The gap that does the work a card would.
    public static let betweenSections: CGFloat = 28

    /// The thickness of a rule. See `Hairline`.
    public static let hairline: CGFloat = 0.5
}
