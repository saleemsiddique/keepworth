import Testing

@testable import KeepworthDomain

/// €42.30 of groceries, shaped the way the use case builds it.
private func groceryExpenseLines(
    account: AccountID,
    category: AccountID
) -> [EntryLine] {
    [
        EntryLine(accountID: account, amount: Money(minorUnits: -4230, currency: .eur)),
        EntryLine(accountID: category, amount: Money(minorUnits: 4230, currency: .eur)),
    ]
}

@Test("An entry whose lines sum to zero is accepted")
func acceptsBalancedEntry() throws {
    let lines = groceryExpenseLines(account: AccountID(), category: AccountID())

    let entry = try Entry(
        occurredOn: CalendarDate(year: 2026, month: 1, day: 31),
        payee: "Mercadona",
        lines: lines
    )

    #expect(entry.lines.count == 2)
    #expect(entry.payee == "Mercadona")
}

@Test("An entry whose lines do not sum to zero is rejected")
func rejectsUnbalancedEntry() throws {
    let lines = [
        EntryLine(accountID: AccountID(), amount: Money(minorUnits: -4230, currency: .eur)),
        EntryLine(accountID: AccountID(), amount: Money(minorUnits: 4200, currency: .eur)),
    ]

    #expect(throws: EntryError.unbalanced(residual: Money(minorUnits: -30, currency: .eur))) {
        try Entry(occurredOn: CalendarDate(year: 2026, month: 1, day: 31), lines: lines)
    }
}

@Test("A single-line entry is rejected")
func rejectsSingleLineEntry() throws {
    let lines = [
        EntryLine(accountID: AccountID(), amount: Money.zero(in: .eur))
    ]

    #expect(throws: EntryError.needsAtLeastTwoLines(found: 1)) {
        try Entry(occurredOn: CalendarDate(year: 2026, month: 1, day: 31), lines: lines)
    }
}

@Test("An entry with no lines is rejected")
func rejectsEntryWithoutLines() throws {
    #expect(throws: EntryError.needsAtLeastTwoLines(found: 0)) {
        try Entry(occurredOn: CalendarDate(year: 2026, month: 1, day: 31), lines: [])
    }
}

@Test("An entry with mixed base currencies is rejected")
func rejectsMixedBaseCurrencies() throws {
    let lines = [
        EntryLine(accountID: AccountID(), amount: Money(minorUnits: -100, currency: .eur)),
        EntryLine(accountID: AccountID(), amount: Money(minorUnits: 100, currency: .usd)),
    ]

    #expect(throws: EntryError.mixedBaseCurrencies) {
        try Entry(occurredOn: CalendarDate(year: 2026, month: 1, day: 31), lines: lines)
    }
}

@Test("A three-line entry balances if its base currency total is zero")
func acceptsThreeLineEntry() throws {
    // Selling 0.5 BTC bought for €30,000 at €35,000: the gain is the third line, and the
    // entry would not balance without it.
    let lines = [
        EntryLine(
            accountID: AccountID(),
            amount: Money(minorUnits: -50_000_000, currency: .eur),
            baseAmount: Money(minorUnits: -3_000_000, currency: .eur)
        ),
        EntryLine(
            accountID: AccountID(),
            amount: Money(minorUnits: 3_500_000, currency: .eur),
            baseAmount: Money(minorUnits: 3_500_000, currency: .eur)
        ),
        EntryLine(
            accountID: AccountID(),
            amount: Money(minorUnits: -500_000, currency: .eur),
            baseAmount: Money(minorUnits: -500_000, currency: .eur)
        ),
    ]

    let entry = try Entry(occurredOn: CalendarDate(year: 2026, month: 1, day: 31), lines: lines)

    #expect(entry.lines.count == 3)
}

@Test("An entry balances on the base amount, not on the account amount")
func balancesByBaseAmountNotAccountAmount() throws {
    // The two lines move different amounts in their own currencies but the same value in
    // base currency, which is what has to balance.
    let lines = [
        EntryLine(
            accountID: AccountID(),
            amount: Money(minorUnits: -3_000_000, currency: .eur),
            baseAmount: Money(minorUnits: -3_000_000, currency: .eur)
        ),
        EntryLine(
            accountID: AccountID(),
            amount: Money(minorUnits: 50_000_000, currency: .usd),
            baseAmount: Money(minorUnits: 3_000_000, currency: .eur)
        ),
    ]

    let entry = try Entry(occurredOn: CalendarDate(year: 2026, month: 1, day: 31), lines: lines)

    #expect(entry.baseCurrency == .eur)
}

@Test("A blank payee is stored as absent")
func storesBlankPayeeAsAbsent() throws {
    let lines = groceryExpenseLines(account: AccountID(), category: AccountID())

    let entry = try Entry(
        occurredOn: CalendarDate(year: 2026, month: 1, day: 31),
        payee: "   ",
        lines: lines
    )

    #expect(entry.payee == nil)
}
