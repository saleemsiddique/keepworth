import SwiftUI

/// What a section says when it has nothing to show: one line, no illustration.
///
/// "Sin movimientos. Añade el primero." A drawing and a headline would make emptiness feel
/// like a failure, when on the first launch it is simply the truth.
public struct EmptyStateLine: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.rowSubtitle)
            .foregroundStyle(.inkSoft)
            .padding(.vertical, Spacing.row)
    }
}

private struct EmptyStateLinePreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption("Reciente")
            EmptyStateLine("Sin movimientos. Añade el primero.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.screenMargin)
        .background(.bg)
    }
}

#Preview("Light") {
    EmptyStateLinePreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    EmptyStateLinePreview().preferredColorScheme(.dark)
}
