import KeepworthDomain
import Testing

@testable import KeepworthPersistence

private func ledgerWithOneExpense() async throws -> (ledger: StoredLedger, entry: Entry) {
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
    return (ledger, entry)
}

@Test("A deleted movement leaves every list it was in")
func deletedMovementLeavesEveryList() async throws {
    let (ledger, entry) = try await ledgerWithOneExpense()
    let cash = try await ledger.account(named: "Efectivo")

    try await ledger.entries.delete(entry.id)

    #expect(try await ledger.entries.entries(matching: try EntryQuery(limit: 10)).isEmpty)
    // And out of the derived figures too, which is the half a screen would notice last.
    #expect(
        try await ledger.entries.lines(matching: EntryLineQuery(accountIDs: [cash.id])).isEmpty
    )
}

@Test("Deleting buries the lines as well as the entry")
func deletingBuriesTheLinesToo() async throws {
    let (ledger, entry) = try await ledgerWithOneExpense()

    try await ledger.entries.delete(entry.id)

    // Reads already ignore a line whose entry is buried, so entry-only would look right on
    // screen. A line with no tombstone of its own is a line the sync has no reason to remove
    // anywhere else, and it comes back on the next round trip.
    let liveLines = try await ledger.database.writer.read { db in
        try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM entry_line WHERE entry_id = ? AND deleted_at IS NULL",
            arguments: [entry.id.rawValue.uuidString]
        )
    }
    #expect(liveLines == 0)
}

@Test("Nothing is removed from the tables, only marked")
func nothingIsRemovedOnlyMarked() async throws {
    let (ledger, entry) = try await ledgerWithOneExpense()

    try await ledger.entries.delete(entry.id)

    // A row that vanishes leaves nothing for the next sync to notice, so it returns from
    // another device as if it had never been removed.
    let rows = try await ledger.database.writer.read { db in
        try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM entry_line WHERE entry_id = ?",
            arguments: [entry.id.rawValue.uuidString]
        )
    }
    #expect(rows == 2)
}

@Test("Undo brings the movement back whole")
func undoBringsTheMovementBackWhole() async throws {
    let (ledger, entry) = try await ledgerWithOneExpense()
    try await ledger.entries.delete(entry.id)

    try await ledger.entries.restore(entry)

    let found = try await ledger.entries.entries(matching: try EntryQuery(limit: 10))
    #expect(found.count == 1)
    // Whole, not just the header: an entry short of a leg does not sum to zero, and reading
    // it would throw rather than come back wrong.
    #expect(found.first?.lines.count == 2)
    #expect(found.first?.payee == "Mercadona")
}

@Test("Undo does not resurrect a line an earlier edit had already buried")
func undoDoesNotResurrectAnEarlierEdit() async throws {
    let (ledger, entry) = try await ledgerWithOneExpense()
    let cash = try await ledger.account(named: "Efectivo")
    let housing = try await ledger.account(named: "Vivienda")

    // Edit it onto another category: the old line is buried now. With the ledger's fixed
    // clock both burials share a timestamp, which is exactly the case that broke the first
    // attempt at this.
    let edited = try Entry(
        id: entry.id,
        occurredOn: entry.occurredOn,
        payee: entry.payee,
        lines: [
            EntryLine(accountID: cash.id, amount: euros(-4230)),
            EntryLine(accountID: housing.id, amount: euros(4230)),
        ]
    )
    try await ledger.entries.save(edited)
    try await ledger.entries.delete(entry.id)

    try await ledger.entries.restore(edited)

    // Three lines exist in the table; only the two buried by the delete come back. Reviving
    // all of them would give a four-legged entry that does not balance.
    let found = try await ledger.entries.entries(matching: try EntryQuery(limit: 10))
    #expect(found.first?.lines.count == 2)
    #expect(found.first?.lines.contains { $0.accountID == housing.id } == true)
}

@Test("Deleting a movement that is not there says so")
func deletingSomethingAbsentSaysSo() async throws {
    let (ledger, entry) = try await ledgerWithOneExpense()
    try await ledger.entries.delete(entry.id)

    // Deleting twice is a caller mistake, not a no-op to swallow: it means a screen is acting
    // on a movement it should no longer be holding.
    await #expect(throws: RepositoryError.entryNotFound(entry.id)) {
        try await ledger.entries.delete(entry.id)
    }
}

@Test("Restoring something that was never deleted says so")
func restoringSomethingLiveSaysSo() async throws {
    let (ledger, entry) = try await ledgerWithOneExpense()

    // Not a no-op to swallow: it means a screen is offering an undo for something that is
    // still there.
    await #expect(throws: RepositoryError.entryNotFound(entry.id)) {
        try await ledger.entries.restore(entry)
    }
}

@Test("Deleting a movement rings the change signal")
func deletingRingsTheSignal() async throws {
    let (ledger, entry) = try await ledgerWithOneExpense()
    let stream = SQLiteLedgerChanges(database: ledger.database).changes()

    async let signalled = receivedSignal(from: stream)
    try await ledger.entries.delete(entry.id)

    // Without this the summary keeps showing a movement the user just removed.
    #expect(try await signalled)
}
