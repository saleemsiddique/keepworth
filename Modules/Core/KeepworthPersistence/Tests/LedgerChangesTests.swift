import KeepworthDomain
import Testing

@testable import KeepworthPersistence

/// Waits for one signal, giving up rather than hanging the suite if it never comes.
///
/// The wait is generous where a signal is expected, because it is never actually paid: the
/// answer arrives as soon as the observation fires. Where **no** signal is expected the wait
/// is paid in full every run, so that one is kept short.
private func receivedSignal(
    from stream: AsyncThrowingStream<Void, any Error>,
    waiting timeout: Duration = .seconds(5)
) async throws -> Bool {
    try await withThrowingTaskGroup(of: Bool.self) { group in
        group.addTask {
            var iterator = stream.makeAsyncIterator()
            return try await iterator.next() != nil
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            return false
        }
        let first = try await group.next() ?? false
        group.cancelAll()
        return first
    }
}

@Test("Writing an entry rings the signal")
func writingAnEntryRingsTheSignal() async throws {
    let ledger = try StoredLedger()
    try await ledger.seed()
    let cash = try await ledger.account(named: "Efectivo")
    let groceries = try await ledger.account(named: "Supermercado")
    let stream = SQLiteLedgerChanges(database: ledger.database).changes()

    async let signalled = receivedSignal(from: stream)
    _ = try await RecordExpense(accounts: ledger.accounts, entries: ledger.entries)
        .execute(
            RecordExpense.Request(
                accountID: cash.id,
                categoryID: groceries.id,
                amount: euros(4230),
                occurredOn: try day(2026, 1, 31),
                payee: "Mercadona"
            )
        )

    #expect(try await signalled)
}

@Test("A write to any table rings it, not only to the entry tables")
func anyTableRingsTheSignal() async throws {
    let ledger = try StoredLedger()
    let stream = SQLiteLedgerChanges(database: ledger.database).changes()

    // `app_setting`, which no screen shows directly. The signal says the ledger moved, and
    // the base currency moving changes every figure on screen.
    async let signalled = receivedSignal(from: stream)
    try await ledger.settings.setBaseCurrency(.eur)

    #expect(try await signalled)
}

@Test("Two screens both hear the same write, from one observation")
func twoScreensBothHearTheSameWrite() async throws {
    let ledger = try StoredLedger()
    // One observer, two listeners. `changes()` does not start an observation of its own:
    // `DatabaseRegionObservation.start` blocks until it can take write access, so doing that
    // per screen would freeze the main actor while an import runs.
    let observer = SQLiteLedgerChanges(database: ledger.database)
    let summary = observer.changes()
    let transactions = observer.changes()

    async let heardBySummary = receivedSignal(from: summary)
    async let heardByTransactions = receivedSignal(from: transactions)
    try await ledger.settings.setBaseCurrency(.eur)

    #expect(try await heardBySummary)
    #expect(try await heardByTransactions)
}

@Test("Reads ring nothing, and the same observer still rings on a write")
func readsRingNothingButWritesStillDo() async throws {
    let ledger = try StoredLedger()
    try await ledger.seed()
    let observer = SQLiteLedgerChanges(database: ledger.database)

    // Without this the signal would fire on every screen load and each screen would reload
    // itself forever.
    async let afterReads = receivedSignal(from: observer.changes(), waiting: .seconds(1))
    _ = try await ledger.accounts.accounts(ofKinds: [.asset])
    _ = try await ledger.entries.entries(matching: try EntryQuery(limit: 10))
    #expect(try await afterReads == false)

    // The second half is what stops the first from being vacuous: an observation that never
    // fired at all would satisfy the silence above and fail right here. A second stream and
    // not the first one again, because an `AsyncThrowingStream` takes one consumer and the
    // wait above already spent it.
    async let afterWrite = receivedSignal(from: observer.changes())
    try await ledger.settings.setBaseCurrency(.eur)
    #expect(try await afterWrite)
}
