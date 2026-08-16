import KeepworthDomain
import Testing

@testable import FeatureSupport

// Under the Swift 6 language mode, conforming to `View` isolates the initialiser to the main
// actor, so any test building a view must be isolated too.
@MainActor
@Test("A movement row builds from an entry and the names around it")
func movementRowBuilds() throws {
    let cash = try Account(name: "Efectivo", kind: .asset, currency: .eur)
    let groceries = try Account(name: "Supermercado", kind: .expense, currency: .eur)
    let entry = try Entry(
        occurredOn: try CalendarDate(year: 2026, month: 1, day: 31),
        payee: "Mercadona",
        lines: [
            EntryLine(accountID: cash.id, amount: Money(minorUnits: -4230, currency: .eur)),
            EntryLine(accountID: groceries.id, amount: Money(minorUnits: 4230, currency: .eur)),
        ]
    )

    _ = MovementRow(
        entry: entry,
        accountNames: [cash.id: cash.name, groceries.id: groceries.name],
        moneyAccountIDs: [cash.id],
        formatter: MoneyFormatter()
    )
}
