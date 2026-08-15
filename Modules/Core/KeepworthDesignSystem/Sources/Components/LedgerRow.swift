import SwiftUI

/// One line of the ledger: what it is on the left, what it was worth on the right.
///
/// The amount is monospaced so the decimal points line up down a column, which is what lets a
/// list of figures be read without reading it.
///
/// `isIncoming` is the one place the accent appears in a row. Everything else is `ink`,
/// **expenses included**: the app does not paint spending red, because it is not there to tell
/// the user off. A boolean parameter is usually a smell, but this one picks a colour rather
/// than branching behaviour, and splitting the view in two would duplicate the whole layout.
public struct LedgerRow: View {
    private let title: String
    private let subtitle: String?
    private let symbolName: String?
    private let amount: String
    private let isIncoming: Bool

    public init(
        title: String,
        subtitle: String? = nil,
        symbolName: String? = nil,
        amount: String,
        isIncoming: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.amount = amount
        self.isIncoming = isIncoming
    }

    public var body: some View {
        HStack(spacing: Spacing.withinBlock) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.rowSubtitle)
                    .fontWeight(.light)
                    .foregroundStyle(.inkSoft)
            }

            VStack(alignment: .leading, spacing: Spacing.withinLine) {
                Text(title)
                    .font(.rowTitle)
                    .foregroundStyle(.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(.rowSubtitle)
                        .foregroundStyle(.inkSoft)
                }
            }

            Spacer(minLength: Spacing.withinBlock)

            Text(amount)
                .font(.rowAmount)
                .foregroundStyle(amountColor)
                .contentTransition(.numericText())
        }
        .padding(.vertical, Spacing.row)
    }

    private var amountColor: Color {
        isIncoming ? .accent : .ink
    }
}

private struct LedgerRowPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            LedgerRow(title: "BBVA", amount: "20.500,00")
            Hairline()
            LedgerRow(
                title: "Nómina",
                subtitle: "BBVA",
                symbolName: "banknote",
                amount: "1.200,00"
            )
            Hairline()
            LedgerRow(
                title: "Mercadona",
                subtitle: "Supermercado",
                symbolName: "cart",
                amount: "−42,30"
            )
            Hairline()
            LedgerRow(
                title: "Nómina",
                subtitle: "15 de enero",
                symbolName: "arrow.down",
                amount: "+2.100,00",
                isIncoming: true
            )
        }
        .padding(.horizontal, Spacing.screenMargin)
        .background(.bg)
    }
}

#Preview("Light") {
    LedgerRowPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    LedgerRowPreview().preferredColorScheme(.dark)
}
