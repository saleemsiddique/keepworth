import Foundation
import GRDB
import KeepworthDomain
import Testing

@testable import KeepworthPersistence

@Test("The first launch seed leaves a usable ledger on disk")
func seedsAUsableLedger() async throws {
    let ledger = try StoredLedger()

    try await ledger.seed()

    #expect(try await ledger.settings.baseCurrency() == .eur)
    #expect(try await ledger.accounts.accounts(ofKinds: [.asset]).map(\.name) == ["Efectivo"])
    #expect(try await ledger.accounts.accounts(ofKinds: [.expense]).count == 2)
    #expect(try await ledger.accounts.accounts(ofKinds: [.equity]).first?.isSystem == true)
}

@Test("An entry and its lines are stored together and read back identical")
func roundTripsAnEntry() async throws {
    let ledger = try StoredLedger()
    try await ledger.seed()
    let cash = try await ledger.account(named: "Efectivo")
    let groceries = try await ledger.account(named: "Supermercado")

    let entry = try await RecordExpense(accounts: ledger.accounts, entries: ledger.entries)
        .execute(
            RecordExpense.Request(
                accountID: cash.id,
                categoryID: groceries.id,
                amount: euros(4230),
                occurredOn: try day(2026, 1, 31),
                payee: "Mercadona"
            )
        )

    let stored = try await ledger.entries.lines(
        matching: EntryLineQuery(accountIDs: [cash.id, groceries.id])
    )
    #expect(Set(stored) == Set(entry.lines))
}

@Test("A derived balance matches the sum of the stored lines")
func derivedBalanceMatchesStoredLines() async throws {
    let ledger = try StoredLedger()
    try await ledger.seed()
    let cash = try await ledger.account(named: "Efectivo")
    let groceries = try await ledger.account(named: "Supermercado")
    try await SetOpeningBalance(accounts: ledger.accounts, entries: ledger.entries).execute(
        SetOpeningBalance.Request(
            accountID: cash.id,
            balance: euros(100_000),
            occurredOn: try day(2026, 1, 1)
        )
    )
    try await RecordExpense(accounts: ledger.accounts, entries: ledger.entries).execute(
        RecordExpense.Request(
            accountID: cash.id,
            categoryID: groceries.id,
            amount: euros(4230),
            occurredOn: try day(2026, 1, 10)
        )
    )

    let balance = try await CalculateAccountBalance(
        accounts: ledger.accounts,
        entries: ledger.entries
    ).execute(accountID: cash.id, asOf: try day(2026, 1, 31))

    let rawSum = try await ledger.database.writer.read { database in
        try Int64.fetchOne(
            database,
            sql: "SELECT SUM(amount_minor) FROM live_entry_line WHERE account_id = ?",
            arguments: [cash.id.rawValue.uuidString]
        )
    }
    #expect(balance == euros(95770))
    #expect(balance.minorUnits == rawSum)
}

@Test("Lines of a deleted entry stop counting towards the balance")
func deletedEntryStopsCounting() async throws {
    let ledger = try StoredLedger()
    try await ledger.seed()
    let cash = try await ledger.account(named: "Efectivo")
    let groceries = try await ledger.account(named: "Supermercado")
    let entry = try await RecordExpense(accounts: ledger.accounts, entries: ledger.entries)
        .execute(
            RecordExpense.Request(
                accountID: cash.id,
                categoryID: groceries.id,
                amount: euros(4230),
                occurredOn: try day(2026, 1, 10)
            )
        )

    // Only the entry is marked, not its lines: this is the case that silently unbalances
    // everything if a query reads `entry_line` instead of `live_entry_line`.
    try await ledger.database.writer.write { database in
        try database.execute(
            sql: "UPDATE entry SET deleted_at = ? WHERE id = ?",
            arguments: [Date(), entry.id.rawValue.uuidString]
        )
    }

    let balance = try await CalculateAccountBalance(
        accounts: ledger.accounts,
        entries: ledger.entries
    ).execute(accountID: cash.id, asOf: try day(2026, 1, 31))
    #expect(balance == Money.zero(in: .eur))

    let orphanLines = try await ledger.database.writer.read { database in
        try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM entry_line")
    }
    #expect(orphanLines == 2)
}

@Test("Net worth over the stored ledger matches what the report says was saved")
func netWorthMatchesTheReportOnDisk() async throws {
    let ledger = try StoredLedger()
    try await ledger.seed()
    let cash = try await ledger.account(named: "Efectivo")
    let groceries = try await ledger.account(named: "Supermercado")
    let salary = try await ledger.account(named: "Nómina")
    try await RecordIncome(accounts: ledger.accounts, entries: ledger.entries).execute(
        RecordIncome.Request(
            accountID: cash.id,
            categoryID: salary.id,
            amount: euros(210_000),
            occurredOn: try day(2026, 1, 25)
        )
    )
    try await RecordExpense(accounts: ledger.accounts, entries: ledger.entries).execute(
        RecordExpense.Request(
            accountID: cash.id,
            categoryID: groceries.id,
            amount: euros(4230),
            occurredOn: try day(2026, 1, 10)
        )
    )

    let netWorth = CalculateNetWorth(accounts: ledger.accounts, entries: ledger.entries)
    let change =
        try await netWorth.execute(asOf: try day(2026, 1, 31), in: .eur)
        - netWorth.execute(asOf: try day(2025, 12, 31), in: .eur)
    let summary = try await SummarizePeriod(accounts: ledger.accounts, entries: ledger.entries)
        .execute(from: try day(2026, 1, 1), through: try day(2026, 1, 31), in: .eur)

    #expect(summary.netWorthChange == change)
    #expect(summary.netWorthChange == euros(205_770))
}

@Test("A future-dated movement is stored but stays out of today's net worth")
func futureMovementIsStoredButNotCounted() async throws {
    let ledger = try StoredLedger()
    try await ledger.seed()
    let cash = try await ledger.account(named: "Efectivo")
    let rent = try await ledger.account(named: "Vivienda")
    try await RecordExpense(accounts: ledger.accounts, entries: ledger.entries).execute(
        RecordExpense.Request(
            accountID: cash.id,
            categoryID: rent.id,
            amount: euros(80000),
            occurredOn: try day(2026, 2, 1)
        )
    )

    let netWorth = CalculateNetWorth(accounts: ledger.accounts, entries: ledger.entries)

    #expect(try await netWorth.execute(asOf: try day(2026, 1, 31), in: .eur).isZero)
    #expect(try await netWorth.execute(asOf: try day(2026, 2, 1), in: .eur) == euros(-80000))
}

@Test("Reading lines before the ledger has a currency fails instead of guessing one")
func refusesToReadLinesWithoutBaseCurrency() async throws {
    let ledger = try StoredLedger()
    let account = try Account(name: "Efectivo", kind: .asset, currency: .eur)
    try await ledger.accounts.save(account)

    await #expect(throws: RecordError.missingBaseCurrency) {
        try await ledger.entries.lines(matching: EntryLineQuery(accountIDs: [account.id]))
    }
}

@Test("Re-saving an entry with fewer lines buries the ones it dropped")
func resavingBuriesDroppedLines() async throws {
    let ledger = try StoredLedger()
    try await ledger.seed()
    let cash = try await ledger.account(named: "Efectivo")
    let groceries = try await ledger.account(named: "Supermercado")
    let rent = try await ledger.account(named: "Vivienda")

    // Three lines: 100 out of cash, split across two categories.
    let threeLines = try Entry(
        occurredOn: try day(2026, 1, 10),
        lines: [
            EntryLine(accountID: cash.id, amount: euros(-10000)),
            EntryLine(accountID: groceries.id, amount: euros(6000)),
            EntryLine(accountID: rent.id, amount: euros(4000)),
        ]
    )
    try await ledger.entries.save(threeLines)

    // Edited down to two, which is what a Phase 5 editor will do.
    let twoLines = try Entry(
        id: threeLines.id,
        occurredOn: threeLines.occurredOn,
        lines: [
            EntryLine(id: threeLines.lines[0].id, accountID: cash.id, amount: euros(-6000)),
            EntryLine(id: threeLines.lines[1].id, accountID: groceries.id, amount: euros(6000)),
        ]
    )
    try await ledger.entries.save(twoLines)

    let live = try await ledger.entries.lines(
        matching: EntryLineQuery(accountIDs: [cash.id, groceries.id, rent.id])
    )
    #expect(live.count == 2)
    // The stored entry still balances. Leaving the third line alive would have left it at
    // −4000 without a single symptom.
    #expect(try Money.sum(live.map(\.baseAmount), in: .eur).isZero)
}

@Test("Saving an entity whose row is soft-deleted does not resurrect it")
func savingDoesNotClearATombstone() async throws {
    let ledger = try StoredLedger()
    let account = try Account(name: "Efectivo", kind: .asset, currency: .eur)
    try await ledger.accounts.save(account)
    let deletionDate = Date(timeIntervalSince1970: 1_767_312_000)
    try await ledger.database.writer.write { database in
        try database.execute(
            sql: "UPDATE account SET deleted_at = ? WHERE id = ?",
            arguments: [deletionDate, account.id.rawValue.uuidString]
        )
    }

    try await ledger.accounts.save(
        Account(id: account.id, name: "Cash", kind: .asset, currency: .eur)
    )

    let tombstone = try await ledger.database.writer.read { database in
        try Date.fetchOne(
            database,
            sql: "SELECT deleted_at FROM account WHERE id = ?",
            arguments: [account.id.rawValue.uuidString]
        )
    }
    // Clearing it would bring the row back on the next sync, which is exactly what the
    // tombstone exists to prevent.
    #expect(tombstone == deletionDate)
}
