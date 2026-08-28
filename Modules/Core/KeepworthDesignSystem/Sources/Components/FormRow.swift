import SwiftUI

/// A row that says what it holds and opens something when tapped: the account, the category,
/// the date.
///
/// The value sits where an amount sits in `LedgerRow`, so a form reads down the same right
/// edge as the ledger does. `inkSoft` and not `ink`, because the label is the fixed part and
/// the value is what the user came to change — and a placeholder for a value not chosen yet
/// has to look unchosen.
public struct FormRow: View {
    private let title: String
    private let value: String
    private let action: () -> Void

    public init(title: String, value: String, action: @escaping () -> Void) {
        self.title = title
        self.value = value
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.withinBlock) {
                Text(title)
                    .font(.rowTitle)
                    .foregroundStyle(.ink)

                Spacer(minLength: Spacing.withinBlock)

                Text(value)
                    .font(.rowTitle)
                    .foregroundStyle(.inkSoft)
                    .multilineTextAlignment(.trailing)

                Image(systemName: "chevron.right")
                    .font(.rowSubtitle)
                    .fontWeight(.light)
                    .foregroundStyle(.inkSoft)
            }
            .padding(.vertical, Spacing.row)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct FormRowPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            FormRow(title: "Cuenta", value: "Efectivo") {}
            Hairline()
            FormRow(title: "Categoría", value: "Supermercado") {}
            Hairline()
            FormRow(title: "Fecha", value: "28 de agosto de 2026") {}
            Hairline()
            FormRow(title: "Banco", value: "Ninguno") {}
        }
        .padding(.horizontal, Spacing.screenMargin)
        .background(.bg)
    }
}

#Preview("Light") {
    FormRowPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    FormRowPreview().preferredColorScheme(.dark)
}
