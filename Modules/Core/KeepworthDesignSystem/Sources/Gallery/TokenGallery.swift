import SwiftUI

/// Every colour token next to its name, so the palette can be checked in both themes at once.
/// `accent` and `expense` sit last and adjacent on purpose: they are a pair, and the point is
/// that neither shouts louder than the other.
///
/// A development tool, not a screen. Its text is `Text(verbatim:)` and stays out of the String
/// Catalog on purpose: token names are code, and translating them would make the gallery lie
/// about what a caller has to type.
public struct TokenGallery: View {
    private static let swatches: [(name: String, color: Color)] = [
        ("bg", .bg),
        ("surface", .surface),
        ("ink", .ink),
        ("inkSoft", .inkSoft),
        ("hairline", .hairline),
        ("accent", .accent),
        ("expense", .expense),
    ]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.betweenSections) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionCaption("Colour")
                    ForEach(Self.swatches, id: \.name) { swatch in
                        swatchRow(name: swatch.name, color: swatch.color)
                        Hairline()
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.row) {
                    SectionCaption("Type")
                    Text(verbatim: "headlineAmount 1.234,56").font(.headlineAmount)
                    Text(verbatim: "rowAmount 1.234,56").font(.rowAmount)
                    Text(verbatim: "rowTitle").font(.rowTitle)
                    Text(verbatim: "rowSubtitle").font(.rowSubtitle)
                    Text(verbatim: "primaryAction").font(.primaryAction)
                    SectionCaption("sectionCaption")
                }
                .foregroundStyle(.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.screenMargin)
        }
        .background(.bg)
    }

    private func swatchRow(name: String, color: Color) -> some View {
        HStack(spacing: Spacing.withinBlock) {
            // A border, because `bg` on `bg` and `surface` in light mode are otherwise
            // invisible — which is exactly the pair worth being able to see.
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 44, height: 28)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.hairline, lineWidth: 1))

            Text(verbatim: name)
                .font(.rowTitle)
                .foregroundStyle(.ink)

            Spacer()
        }
        .padding(.vertical, Spacing.row)
    }
}

#Preview("Light") {
    TokenGallery().preferredColorScheme(.light)
}

#Preview("Dark") {
    TokenGallery().preferredColorScheme(.dark)
}
