import Testing

@testable import KeepworthDomain

@Test("A non-positive limit is rejected")
func nonPositiveLimitIsRejected() throws {
    // Not pedantry: SQLite reads a negative LIMIT as no limit at all, so letting one reach
    // the persistence layer would turn the guard into an unbounded scan of the whole history.
    #expect(throws: EntryQueryError.limitMustBePositive(0)) {
        _ = try EntryQuery(limit: 0)
    }
    #expect(throws: EntryQueryError.limitMustBePositive(-1)) {
        _ = try EntryQuery(limit: -1)
    }
}

@Test("A query with no account filter means any account")
func noAccountFilterMeansAnyAccount() throws {
    #expect(try EntryQuery(limit: 1).accountIDs == nil)
}

/// The tests below pin the behaviour of `InMemoryEntryRepository`, which is what every feature
/// of phase 4 onwards will be tested against. A double that orders or filters differently from
/// `SQLiteEntryRepository` proves something production does not do.
private func ledgerWithThreeExpenses() async throws -> (
    ledger: Ledger, entries: InMemoryEntryRepository, dates: [CalendarDate]
) {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let expense = RecordExpense(accounts: ledger.accounts, entries: entries)

    let dates = [
        try CalendarDate(year: 2026, month: 1, day: 10),
        try CalendarDate(year: 2026, month: 1, day: 20),
        try CalendarDate(year: 2026, month: 1, day: 30),
    ]
    for (date, payee) in zip(dates, ["Mercadona", "Alquiler", "Consum"]) {
        _ = try await expense.execute(
            RecordExpense.Request(
                accountID: ledger.cash.id,
                categoryID: payee == "Alquiler" ? ledger.rent.id : ledger.groceries.id,
                amount: Money(minorUnits: 1000, currency: .eur),
                occurredOn: date,
                payee: payee
            )
        )
    }
    return (ledger, entries, dates)
}

@Test("The double returns entries newest first, like the stored one")
func doubleReturnsEntriesNewestFirst() async throws {
    let (_, entries, _) = try await ledgerWithThreeExpenses()

    let found = try await entries.entries(matching: try EntryQuery(limit: 10))

    #expect(found.map(\.payee) == ["Consum", "Alquiler", "Mercadona"])
}

@Test("The double breaks ties between same-day entries by when they were saved")
func doubleBreaksSameDayTiesBySaveOrder() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let expense = RecordExpense(accounts: ledger.accounts, entries: entries)
    let sameDay = try CalendarDate(year: 2026, month: 1, day: 15)

    for payee in ["Primero", "Segundo", "Tercero"] {
        _ = try await expense.execute(
            RecordExpense.Request(
                accountID: ledger.cash.id,
                categoryID: ledger.groceries.id,
                amount: Money(minorUnits: 1000, currency: .eur),
                occurredOn: sameDay,
                payee: payee
            )
        )
    }

    let found = try await entries.entries(matching: try EntryQuery(limit: 10))

    // The stored one breaks this tie with `created_at DESC`. Without an equivalent here the
    // double would hand back insertion order — the exact opposite.
    #expect(found.map(\.payee) == ["Tercero", "Segundo", "Primero"])
}

@Test("The double caps at the limit, keeping the newest")
func doubleCapsAtTheLimit() async throws {
    let (_, entries, _) = try await ledgerWithThreeExpenses()

    let found = try await entries.entries(matching: try EntryQuery(limit: 2))

    #expect(found.map(\.payee) == ["Consum", "Alquiler"])
}

@Test("The double filters by account and keeps every line of what it returns")
func doubleFiltersByAccountKeepingEveryLine() async throws {
    let (ledger, entries, _) = try await ledgerWithThreeExpenses()

    let found = try await entries.entries(
        matching: try EntryQuery(accountIDs: [ledger.rent.id], limit: 10)
    )

    #expect(found.map(\.payee) == ["Alquiler"])
    // Both legs, not only the one the filter matched: a subset would not sum to zero.
    #expect(found.first?.lines.count == 2)
}

@Test("The double includes both ends of the date range")
func doubleIncludesBothEndsOfTheRange() async throws {
    let (_, entries, dates) = try await ledgerWithThreeExpenses()

    let found = try await entries.entries(
        matching: try EntryQuery(from: dates[0], through: dates[2], limit: 10)
    )

    #expect(found.count == 3)
}

@Test("Re-saving an entry in the double replaces it instead of duplicating it")
func doubleReplacesOnReSave() async throws {
    let (ledger, entries, dates) = try await ledgerWithThreeExpenses()
    let original = try await entries.entries(matching: try EntryQuery(limit: 1))[0]

    try await entries.save(
        try Entry(
            id: original.id,
            occurredOn: dates[2],
            payee: "Consum Express",
            lines: [
                EntryLine(
                    accountID: ledger.cash.id, amount: Money(minorUnits: -2500, currency: .eur)),
                EntryLine(
                    accountID: ledger.groceries.id,
                    amount: Money(minorUnits: 2500, currency: .eur)
                ),
            ]
        )
    )

    let found = try await entries.entries(matching: try EntryQuery(limit: 10))
    #expect(found.count == 3)
    #expect(found[0].payee == "Consum Express")
}
