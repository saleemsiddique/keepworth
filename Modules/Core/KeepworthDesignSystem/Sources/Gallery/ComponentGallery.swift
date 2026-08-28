import SwiftUI

/// Every component arranged as a screen would arrange them, because a component looks right
/// on its own and wrong next to its neighbours.
///
/// This is the visual review tool of the project: a new component that does not appear here is
/// not finished. Reviewed in both themes — the dark one is where a literal colour gives itself
/// away.
///
/// A development tool, not a screen. Its strings are hard-coded sample data and stay out of the
/// String Catalog; the components take plain `String`, so nothing here is localisable anyway.
public struct ComponentGallery: View {
    @State private var selection = Destination.summary
    @State private var movementType = MovementType.expense
    @State private var chosenAccount: String? = "Efectivo"
    @State private var payee = "Mercadona"
    @State private var typedAmount = DigitAmount(minorUnits: 4230)

    private enum Destination {
        case summary
        case transactions
    }

    private enum MovementType {
        case expense
        case income
        case transfer
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
                    editing
                    picking
                    outOfContext
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

    /// Banks with their accounts indented underneath, banks ordered by total and accounts by
    /// balance. Cash, which belongs to no bank, goes loose at the end.
    ///
    /// The indentation is applied here rather than by `LedgerRow` because this is the only
    /// place that nests rows so far. If a later screen nests them too, that is the second use
    /// that earns extracting it.
    private var accounts: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption("Cuentas")

            LedgerRow(title: "BBVA", amount: "20.500,00")
            Hairline()
            nested(LedgerRow(title: "Remunerada", amount: "19.300,00"))
            Hairline()
            nested(LedgerRow(title: "Nómina", amount: "1.200,00"))
            Hairline()
            nested(LedgerRow(title: "Visa", amount: "−320,45", direction: .outgoing))
            Hairline()

            LedgerRow(title: "Santander", amount: "8.240,15")
            Hairline()
            nested(LedgerRow(title: "Ahorro", amount: "8.000,00"))
            Hairline()
            nested(LedgerRow(title: "Cuenta", amount: "240,15"))
            Hairline()

            LedgerRow(title: "Trade Republic", amount: "4.060,80")
            Hairline()
            nested(LedgerRow(title: "Cartera", amount: "3.000,00"))
            Hairline()
            nested(LedgerRow(title: "Remunerada", amount: "1.060,80"))
            Hairline()

            LedgerRow(title: "Efectivo", amount: "120,00")
        }
    }

    private func nested(_ row: LedgerRow) -> some View {
        row.padding(.leading, Spacing.screenMargin)
    }

    private var thisMonth: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption("Este mes")
            LedgerRow(title: "Gastado", amount: "−937,30", direction: .outgoing)
            Hairline()
            // `ink`, not the accent: what was saved is a derived figure, not money coming in.
            // The accent belongs to the income row below and to the add button.
            LedgerRow(title: "Ahorrado", amount: "+1.162,70")
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption("Reciente")
            LedgerRow(
                title: "Mercadona",
                subtitle: "Supermercado",
                symbolName: "cart",
                amount: "−42,30",
                direction: .outgoing
            )
            Hairline()
            LedgerRow(
                title: "Iberdrola",
                subtitle: "Suministros",
                symbolName: "bolt",
                amount: "−68,90",
                direction: .outgoing
            )
            Hairline()
            LedgerRow(
                title: "Nómina",
                subtitle: "BBVA · Nómina",
                symbolName: "banknote",
                amount: "+2.100,00",
                direction: .incoming
            )
        }
    }

    private var emptySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption("Programados")
            EmptyStateLine("Sin movimientos. Añade el primero.")
        }
    }

    /// The entry primitives in the shape the movement editor uses them: the type on top, the
    /// figure being typed, the rows that open a picker, and the keypad underneath.
    private var editing: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            SectionCaption("Editar un movimiento")

            ChoiceBar(
                selection: $movementType,
                items: [
                    ChoiceItem(tag: MovementType.expense, title: "Gasto"),
                    ChoiceItem(tag: MovementType.income, title: "Ingreso"),
                    ChoiceItem(tag: MovementType.transfer, title: "Traspaso"),
                ]
            )

            VStack(spacing: 0) {
                FormRow(title: "Cuenta", value: "Efectivo") {}
                Hairline()
                FormRow(title: "Categoría", value: "Supermercado") {}
                Hairline()
                FormRow(title: "Fecha", value: "28 de agosto de 2026") {}
                Hairline()
                TextEntryRow(title: "Beneficiario", prompt: "Opcional", text: $payee)
            }

            AmountKeypad(
                onDigit: { typedAmount.append($0) },
                onDelete: { typedAmount.deleteLast() }
            )
        }
    }

    /// What opens when one of those rows is tapped.
    private var picking: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption("Elegir una cuenta")
            pickerRow("Efectivo", symbol: "banknote")
            Hairline()
            pickerRow("BBVA · Nómina", symbol: "building.columns")
            Hairline()
            pickerRow("Visa", symbol: "creditcard")
        }
    }

    private func pickerRow(_ title: String, symbol: String) -> some View {
        SelectionRow(
            tag: title,
            selection: chosenAccount,
            title: title,
            symbolName: symbol
        ) {
            chosenAccount = title
        }
    }

    /// Components no real screen would put in a summary. They appear under their own heading
    /// so the gallery stays a catalogue rather than a proposal for one screen.
    ///
    /// `SheetSurface` is missing on purpose: it paints a whole modal layer, so showing it here
    /// would mean drawing a sheet inside a scroll. Its own two previews are where it is
    /// reviewed.
    private var outOfContext: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            SectionCaption("Fuera de contexto")
            PrimaryAction("Guardar") {}
            PrimaryAction("Guardar", availability: .unavailable) {}
        }
    }
}

#Preview("Light") {
    ComponentGallery().preferredColorScheme(.light)
}

#Preview("Dark") {
    ComponentGallery().preferredColorScheme(.dark)
}
