import SwiftUI

/// The label above a section: small, uppercase and widely tracked.
///
/// Uppercase and tracking are applied here rather than offered as a font, because the three
/// never travel apart and splitting them invites a caption that only got two of the three.
///
/// Takes a `String` the caller has already localised. This module has no String Catalog and
/// must not grow one: it does not know which of the app's languages is on screen.
public struct SectionCaption: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.sectionCaption)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(.inkSoft)
    }
}

private struct SectionCaptionPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.betweenSections) {
            SectionCaption("Patrimonio")
            SectionCaption("Este mes")
            SectionCaption("Reciente")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.screenMargin)
        .background(.bg)
    }
}

#Preview("Light") {
    SectionCaptionPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    SectionCaptionPreview().preferredColorScheme(.dark)
}
