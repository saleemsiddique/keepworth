import SwiftUI

/// The seven components arranged as a screen would arrange them, because a component looks
/// right on its own and wrong next to its neighbours.
///
/// This is the visual review tool of the project: a new component that does not appear here is
/// not finished. Reviewed in both themes — the dark one is where a literal colour gives itself
/// away.
///
/// A development tool, not a screen. Its strings are hard-coded sample data and stay out of the
/// String Catalog; the components take plain `String`, so nothing here is localisable anyway.
public struct ComponentGallery: View {
    @State private var selection = Destination.summary

    private enum Destination {
        case summary
        case transactions
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.betweenSections) {
                    HeadlineAmount(
                        caption: "Patrimonio",
                        amount: "24.560,80 €",
                        detail: "▲ +1,2 % este mes"
                    )

                    accounts
                    thisMonth
                    recent
                    emptySection

                    PrimaryAction("Guardar") {}
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.screenMargin)
            }

            LedgerTabBar(
                selection: $selection,
                leading: LedgerTabItem(
                    tag: Destination.summary,
                    title: "Resumen",
                    symbolName: "square.stack"
                ),
                trailing: LedgerTabItem(
                    tag: Destination.transactions,
                    title: "Movimientos",
                    symbolName: "list.bullet"
                ),
                centerLabel: "Añadir movimiento",
                centerAction: {}
            )
        }
        .background(.bg)
    }

    private var accounts: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption("Cuentas")
            LedgerRow(title: "BBVA", amount: "20.500,00")
            Hairline()
            LedgerRow(title: "Nómina", subtitle: "BBVA", amount: "1.200,00")
            Hairline()
            LedgerRow(title: "Remunerada", subtitle: "BBVA", amount: "19.300,00")
            Hairline()
            LedgerRow(title: "Visa", subtitle: "BBVA", amount: "−320,45")
        }
    }

    private var thisMonth: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption("Este mes")
            LedgerRow(title: "Gastado", amount: "937,30")
            Hairline()
            // `ink`, not the accent: what was saved is a derived figure, not money coming in.
            // The accent belongs to the income row below and to the add button.
            LedgerRow(title: "Ahorrado", amount: "1.162,70")
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption("Reciente")
            LedgerRow(
                title: "Mercadona",
                subtitle: "Supermercado",
                symbolName: "cart",
                amount: "−42,30"
            )
            Hairline()
            LedgerRow(
                title: "Nómina",
                subtitle: "BBVA · Nómina",
                symbolName: "banknote",
                amount: "+2.100,00",
                isIncoming: true
            )
        }
    }

    private var emptySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption("Programados")
            EmptyStateLine("Sin movimientos. Añade el primero.")
        }
    }
}

#Preview("Light") {
    ComponentGallery().preferredColorScheme(.light)
}

#Preview("Dark") {
    ComponentGallery().preferredColorScheme(.dark)
}
