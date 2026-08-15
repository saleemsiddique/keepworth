import SwiftUI

/// A 0.5 pt rule in the `hairline` token: the only separator the app draws.
///
/// Not `Divider`, which picks its own thickness and a system colour, and so would drift from
/// the palette in one of the two themes without anybody noticing.
public struct Hairline: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(.hairline)
            .frame(height: Spacing.hairline)
    }
}

private struct HairlinePreview: View {
    var body: some View {
        VStack(spacing: Spacing.betweenSections) {
            Hairline()
            Hairline()
        }
        .padding(Spacing.screenMargin)
        .background(.bg)
    }
}

#Preview("Light") {
    HairlinePreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    HairlinePreview().preferredColorScheme(.dark)
}
