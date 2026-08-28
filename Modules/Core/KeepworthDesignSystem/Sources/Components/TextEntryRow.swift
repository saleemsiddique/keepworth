import SwiftUI

/// A row the user types into: the payee, a note, the name of an account.
///
/// Laid out like `FormRow` so a form does not change shape between the rows that open a
/// picker and the rows that take text. The field carries no box of its own — the hairline
/// under the row is the only edge, which is the same way every other row here is bounded.
public struct TextEntryRow: View {
    private let title: String
    private let prompt: String
    @Binding private var text: String

    public init(title: String, prompt: String, text: Binding<String>) {
        self.title = title
        self.prompt = prompt
        self._text = text
    }

    public var body: some View {
        HStack(spacing: Spacing.withinBlock) {
            Text(title)
                .font(.rowTitle)
                .foregroundStyle(.ink)

            Spacer(minLength: Spacing.withinBlock)

            TextField(text: $text) {
                Text(prompt).foregroundStyle(.inkSoft)
            }
            .font(.rowTitle)
            .foregroundStyle(.ink)
            .multilineTextAlignment(.trailing)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled()
        }
        .padding(.vertical, Spacing.row)
    }
}

private struct TextEntryRowPreview: View {
    @State private var payee = "Mercadona"
    @State private var note = ""

    var body: some View {
        VStack(spacing: 0) {
            TextEntryRow(title: "Beneficiario", prompt: "Opcional", text: $payee)
            Hairline()
            TextEntryRow(title: "Nota", prompt: "Opcional", text: $note)
        }
        .padding(.horizontal, Spacing.screenMargin)
        .background(.bg)
    }
}

#Preview("Light") {
    TextEntryRowPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    TextEntryRowPreview().preferredColorScheme(.dark)
}
