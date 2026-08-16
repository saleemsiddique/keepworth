import Testing

@testable import KeepworthDomain

/// Which leg of a movement is "the amount" decides what a row shows and what colour it takes.
/// It is accounting, not drawing, so it is settled here once for every screen.
@Test("An expense reads as the money leaving the account")
func expenseReadsAsMoneyLeaving() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let entry = try await RecordExpense(accounts: ledger.accounts, entries: entries)
        .execute(
            RecordExpense.Request(
                accountID: ledger.cash.id,
                categoryID: ledger.groceries.id,
                amount: Money(minorUnits: 4230, currency: .eur),
                occurredOn: try CalendarDate(year: 2026, month: 1, day: 31),
                payee: "Mercadona"
            )
        )

    let line = try #require(entry.moneyLine(among: [ledger.cash.id]))

    // The category leg is the same number with the other sign; showing it would say +42,30
    // for money the user just spent.
    #expect(line.accountID == ledger.cash.id)
    #expect(line.amount.isNegative)
}

@Test("Income reads as the money arriving")
func incomeReadsAsMoneyArriving() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let entry = try await RecordIncome(accounts: ledger.accounts, entries: entries)
        .execute(
            RecordIncome.Request(
                accountID: ledger.checking.id,
                categoryID: ledger.salary.id,
                amount: Money(minorUnits: 210_000, currency: .eur),
                occurredOn: try CalendarDate(year: 2026, month: 1, day: 25),
                payee: "Nómina"
            )
        )

    let line = try #require(entry.moneyLine(among: [ledger.checking.id]))

    #expect(line.accountID == ledger.checking.id)
    #expect(line.amount.isPositive)
}

@Test("A transfer reads from where the money left, not where it landed")
func transferReadsFromTheOrigin() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let entry = try await TransferBetweenAccounts(accounts: ledger.accounts, entries: entries)
        .execute(
            TransferBetweenAccounts.Request(
                sourceAccountID: ledger.checking.id,
                destinationAccountID: ledger.cash.id,
                amount: Money(minorUnits: 50000, currency: .eur),
                occurredOn: try CalendarDate(year: 2026, month: 1, day: 12)
            )
        )

    // Both legs are money accounts. Read as an arrival, a transfer hides where it came from.
    let line = try #require(entry.moneyLine(among: [ledger.checking.id, ledger.cash.id]))

    #expect(line.accountID == ledger.checking.id)
    #expect(line.amount.isNegative)
}

@Test("The counterpart of a two-line movement is the other leg")
func counterpartIsTheOtherLeg() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let entry = try await RecordExpense(accounts: ledger.accounts, entries: entries)
        .execute(
            RecordExpense.Request(
                accountID: ledger.cash.id,
                categoryID: ledger.groceries.id,
                amount: Money(minorUnits: 4230, currency: .eur),
                occurredOn: try CalendarDate(year: 2026, month: 1, day: 31),
                payee: "Mercadona"
            )
        )
    let money = try #require(entry.moneyLine(among: [ledger.cash.id]))

    let counterpart = try #require(entry.counterpartLine(of: money))

    #expect(counterpart.accountID == ledger.groceries.id)
}

@Test("A movement with three legs has no single counterpart")
func threeLeggedMovementHasNoSingleCounterpart() throws {
    // Selling something that gained value: the difference lands on a third leg, so "the other
    // side" stops being one thing and the row should not invent one.
    let ledger = try Ledger()
    let entry = try Entry(
        occurredOn: try CalendarDate(year: 2026, month: 3, day: 1),
        lines: [
            EntryLine(accountID: ledger.cash.id, amount: Money(minorUnits: 3500, currency: .eur)),
            EntryLine(
                accountID: ledger.checking.id, amount: Money(minorUnits: -3000, currency: .eur)),
            EntryLine(accountID: ledger.salary.id, amount: Money(minorUnits: -500, currency: .eur)),
        ]
    )
    let money = try #require(entry.moneyLine(among: [ledger.cash.id, ledger.checking.id]))

    #expect(entry.counterpartLine(of: money) == nil)
}
