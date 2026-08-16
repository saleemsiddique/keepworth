import Foundation
import KeepworthDesignSystem
import KeepworthDomain
import Testing

@testable import FeatureSupport

private struct Ledger {
    let cash = try! Account(name: "Efectivo", kind: .asset, currency: .eur)
    let card = try! Account(name: "Visa", kind: .liability, currency: .eur)
    let groceries = try! Account(name: "Supermercado", kind: .expense, currency: .eur)
    let salary = try! Account(name: "Nómina", kind: .income, currency: .eur)

    var names: [AccountID: String] {
        [
            cash.id: cash.name, card.id: card.name, groceries.id: groceries.name,
            salary.id: salary.name,
        ]
    }

    var moneyAccountIDs: Set<AccountID> { [cash.id, card.id] }

    func reading(_ entry: Entry) -> MovementReading {
        MovementReading(
            entry: entry,
            accountNames: names,
            moneyAccountIDs: moneyAccountIDs,
            formatter: MoneyFormatter(locale: Locale(identifier: "es_ES"))
        )
    }

    func entry(payee: String?, legs: [(AccountID, Int64)]) throws -> Entry {
        try Entry(
            occurredOn: try CalendarDate(year: 2026, month: 1, day: 31),
            payee: payee,
            lines: legs.map {
                EntryLine(accountID: $0.0, amount: Money(minorUnits: $0.1, currency: .eur))
            }
        )
    }
}

@Test("An expense reads with a minus and takes the expense colour")
func expenseReadsOutgoing() throws {
    let ledger = Ledger()
    let entry = try ledger.entry(
        payee: "Mercadona", legs: [(ledger.cash.id, -4230), (ledger.groceries.id, 4230)])

    let reading = ledger.reading(entry)

    #expect(reading.title == "Mercadona")
    #expect(reading.subtitle == "Efectivo · Supermercado")
    #expect(reading.amount.contains("-42,30"))
    // The loudest rule in the design system, and the one a test that only built the view
    // would let anyone invert.
    #expect(reading.direction == .outgoing)
}

@Test("Income reads with a plus and takes the accent")
func incomeReadsIncoming() throws {
    let ledger = Ledger()
    let entry = try ledger.entry(
        payee: "Nómina", legs: [(ledger.cash.id, 210_000), (ledger.salary.id, -210_000)])

    let reading = ledger.reading(entry)

    // Without the thousands separator: Spanish writes a four-digit number as `2100,00`, and
    // expecting `2.100,00` here would be testing the wrong locale rule rather than the sign.
    #expect(reading.amount.hasPrefix("+"))
    #expect(reading.amount.contains("2100,00"))
    #expect(reading.direction == .incoming)
}

@Test("A transfer reads from the account the money left")
func transferReadsFromTheOrigin() throws {
    let ledger = Ledger()
    let entry = try ledger.entry(
        payee: nil, legs: [(ledger.cash.id, -50000), (ledger.card.id, 50000)])

    let reading = ledger.reading(entry)

    // Both legs hold money. Read as an arrival it would say +500,00 and hide where it came
    // from.
    #expect(reading.direction == .outgoing)
    #expect(reading.amount.contains("-500,00"))
    #expect(reading.title == "Visa")
}

@Test("A movement with no payee is titled by what it was filed under")
func noPayeeIsTitledByTheCategory() throws {
    let ledger = Ledger()
    let entry = try ledger.entry(
        payee: nil, legs: [(ledger.cash.id, -4230), (ledger.groceries.id, 4230)])

    let reading = ledger.reading(entry)

    #expect(reading.title == "Supermercado")
    #expect(reading.subtitle == nil)
}

@Test("A movement with three legs still has a title")
func threeLeggedMovementStillHasATitle() throws {
    let ledger = Ledger()
    // Selling something that gained value: the difference lands on a third leg, so there is
    // no single counterpart to name. The row must not come out with only a figure on it.
    let entry = try ledger.entry(
        payee: nil,
        legs: [(ledger.cash.id, 3500), (ledger.card.id, -3000), (ledger.salary.id, -500)]
    )

    let reading = ledger.reading(entry)

    #expect(!reading.title.isEmpty)
    #expect(!reading.amount.isEmpty)
}

@Test("A movement that touches no money account still renders something")
func movementWithoutMoneyAccountsStillRenders() throws {
    let ledger = Ledger()
    // Cannot happen through a use case, but a corrupt row or a future feature could. Blank is
    // worse than plain.
    let entry = try ledger.entry(
        payee: "Ajuste", legs: [(ledger.groceries.id, 1000), (ledger.salary.id, -1000)])

    let reading = ledger.reading(entry)

    #expect(reading.title == "Ajuste")
    #expect(reading.direction == .neutral)
}
