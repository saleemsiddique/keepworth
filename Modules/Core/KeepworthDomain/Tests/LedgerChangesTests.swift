import Testing

@testable import KeepworthDomain

/// Waits for one signal, giving up rather than hanging the suite if it never comes.
private func receivedSignal(
    from stream: AsyncThrowingStream<Void, any Error>
) async throws -> Bool {
    try await withThrowingTaskGroup(of: Bool.self) { group in
        group.addTask {
            var iterator = stream.makeAsyncIterator()
            return try await iterator.next() != nil
        }
        group.addTask {
            try await Task.sleep(for: .seconds(2))
            return false
        }
        let first = try await group.next() ?? false
        group.cancelAll()
        return first
    }
}

@Test("Saving an entry rings the signal")
func savingAnEntryRingsTheSignal() async throws {
    let ledger = try Ledger()
    let changes = InMemoryLedgerChanges()
    let entries = InMemoryEntryRepository(changes: changes)
    let stream = changes.changes()

    async let signalled = receivedSignal(from: stream)
    _ = try await RecordExpense(accounts: ledger.accounts, entries: entries)
        .execute(
            RecordExpense.Request(
                accountID: ledger.cash.id,
                categoryID: ledger.groceries.id,
                amount: Money(minorUnits: 4230, currency: .eur),
                occurredOn: try CalendarDate(year: 2026, month: 1, day: 31),
                payee: "Mercadona"
            )
        )

    #expect(try await signalled)
}

@Test("Saving an account rings the signal too")
func savingAnAccountRingsTheSignal() async throws {
    let changes = InMemoryLedgerChanges()
    let accounts = InMemoryAccountRepository(changes: changes)
    let stream = changes.changes()

    async let signalled = receivedSignal(from: stream)
    try await accounts.save(try Account(name: "Efectivo", kind: .asset, currency: .eur))

    #expect(try await signalled)
}

@Test("Every listener hears it, not just the first")
func everyListenerHearsIt() async throws {
    let changes = InMemoryLedgerChanges()
    let accounts = InMemoryAccountRepository(changes: changes)
    // Two screens on screen at once is the normal case, not the exotic one.
    let first = changes.changes()
    let second = changes.changes()

    async let heardByFirst = receivedSignal(from: first)
    async let heardBySecond = receivedSignal(from: second)
    try await accounts.save(try Account(name: "Efectivo", kind: .asset, currency: .eur))

    #expect(try await heardByFirst)
    #expect(try await heardBySecond)
}

@Test("A listener that goes away does not break the one that stays")
func aDepartedListenerDoesNotBreakTheRest() async throws {
    let changes = InMemoryLedgerChanges()
    let accounts = InMemoryAccountRepository(changes: changes)
    let staying = changes.changes()

    // A screen that was dismissed: it subscribed, then its task was cancelled, which runs the
    // stream's `onTermination` and takes it off the list. Awaited before writing on purpose —
    // this checks that a departed listener leaves the list clean, not that a departure racing
    // a notification is safe, which no test here covers.
    let leaving = Task {
        for try await _ in changes.changes() { break }
    }
    leaving.cancel()
    _ = try? await leaving.value

    async let heard = receivedSignal(from: staying)
    try await accounts.save(try Account(name: "Efectivo", kind: .asset, currency: .eur))

    #expect(try await heard)
}
