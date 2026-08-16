import SwiftUI

/// Which way the money moved, which is the only thing that colours an amount.
///
/// An enum and not a pair of booleans: there are three cases, and `isIncoming: false` could
/// never say whether a figure was an expense or simply a total.
public enum AmountDirection {
    /// Money coming in. Accent green.
    case incoming
    /// Money going out: an expense, a negative balance, what a period spent. Red.
    case outgoing
    /// Neither — a positive balance, a figure that is only a total. `ink`.
    case neutral
}

/// One line of the ledger: what it is on the left, what it was worth on the right.
///
/// The amount is monospaced so the decimal points line up down a column, which is what lets a
/// list of figures be read without reading it.
///
/// Colour marks **direction**, never judgement: green for what comes in, red for what goes out,
/// `ink` for everything that is neither.
///
/// The sign is redundant with the colour on purpose, and the caller always includes it. Redundant
/// so the figure survives being read in greyscale, by someone who cannot tell the two apart, or
/// copied somewhere with no colour at all.
public struct LedgerRow: View {
    private let title: String
    private let subtitle: String?
    private let symbolName: String?
    private let amount: String
    private let direction: AmountDirection

    public init(
        title: String,
        subtitle: String? = nil,
        symbolName: String? = nil,
        amount: String,
        direction: AmountDirection = .neutral
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.amount = amount
        self.direction = direction
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
        switch direction {
        case .incoming: .accent
        case .outgoing: .expense
        case .neutral: .ink
        }
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
                amount: "−42,30",
                direction: .outgoing
            )
            Hairline()
            LedgerRow(
                title: "Nómina",
                subtitle: "15 de enero",
                symbolName: "arrow.down",
                amount: "+2.100,00",
                direction: .incoming
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
