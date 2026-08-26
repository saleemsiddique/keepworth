import KeepworthDomain
import Testing

@testable import FeatureSupport

/// A repository double that records what it was asked to do. Small on purpose: what these
/// tests are about is the window in which an undo is on offer, not storage.
private actor RecordingEntryRepository: EntryRepository {
    private(set) var deleted: [EntryID] = []
    private(set) var restored: [EntryID] = []
    private var failOn: Failure?

    enum Failure { case delete, restore }

    init(failOn: Failure? = nil) {
        self.failOn = failOn
    }

    func save(_ entry: Entry) async throws {}
    func lines(matching query: EntryLineQuery) async throws -> [EntryLine] { [] }
    func entries(matching query: EntryQuery) async throws -> [Entry] { [] }

    func delete(_ id: EntryID) async throws {
        if failOn == .delete { throw RepositoryError.entryNotFound(id) }
        deleted.append(id)
    }

    func restore(_ entry: Entry) async throws {
        if failOn == .restore { throw RepositoryError.entryNotFound(entry.id) }
        restored.append(entry.id)
    }
}

private func anExpense() throws -> Entry {
    let cash = try Account(name: "Efectivo", kind: .asset, currency: .eur)
    let groceries = try Account(name: "Supermercado", kind: .expense, currency: .eur)
    return try Entry(
        occurredOn: try CalendarDate(year: 2026, month: 1, day: 31),
        payee: "Mercadona",
        lines: [
            EntryLine(accountID: cash.id, amount: Money(minorUnits: -4230, currency: .eur)),
            EntryLine(accountID: groceries.id, amount: Money(minorUnits: 4230, currency: .eur)),
        ]
    )
}

@MainActor
@Test("Deleting offers to undo")
func deletingOffersToUndo() async throws {
    let entries = RecordingEntryRepository()
    let deletion = MovementDeletion(entries: entries)
    let entry = try anExpense()

    await deletion.delete(entry)

    #expect(await entries.deleted == [entry.id])
    #expect(deletion.undoable?.id == entry.id)
}

@MainActor
@Test("Undo puts it back and withdraws the offer")
func undoPutsItBackAndWithdrawsTheOffer() async throws {
    let entries = RecordingEntryRepository()
    let deletion = MovementDeletion(entries: entries)
    let entry = try anExpense()
    await deletion.delete(entry)

    await deletion.undo()

    #expect(await entries.restored == [entry.id])
    // Withdrawn, or a second tap would try to restore something already back and fail.
    #expect(deletion.undoable == nil)
}

@MainActor
@Test("The offer expires on its own")
func theOfferExpiresOnItsOwn() async throws {
    let entries = RecordingEntryRepository()
    let deletion = MovementDeletion(entries: entries, window: .milliseconds(50))
    await deletion.delete(try anExpense())
    #expect(deletion.undoable != nil)

    try await Task.sleep(for: .milliseconds(200))

    // A banner that never goes away is a banner covering the screen.
    #expect(deletion.undoable == nil)
    // And expiring is not undoing: what was deleted stays deleted.
    #expect(await entries.restored.isEmpty)
}

@MainActor
@Test("Undoing after the window has closed does nothing")
func undoAfterTheWindowDoesNothing() async throws {
    let entries = RecordingEntryRepository()
    let deletion = MovementDeletion(entries: entries, window: .milliseconds(50))
    await deletion.delete(try anExpense())
    try await Task.sleep(for: .milliseconds(200))

    await deletion.undo()

    #expect(await entries.restored.isEmpty)
}

@MainActor
@Test("A second delete replaces the offer instead of stacking one")
func secondDeleteReplacesTheOffer() async throws {
    let entries = RecordingEntryRepository()
    let deletion = MovementDeletion(entries: entries)
    let first = try anExpense()
    let second = try anExpense()

    await deletion.delete(first)
    await deletion.delete(second)

    // One banner, offering the last thing removed. The first stays deleted, which is what
    // deleting two in a row means.
    #expect(deletion.undoable?.id == second.id)
    #expect(await entries.deleted == [first.id, second.id])
}

@MainActor
@Test("A delete that fails offers no undo")
func aFailedDeleteOffersNoUndo() async throws {
    let entries = RecordingEntryRepository(failOn: .delete)
    let deletion = MovementDeletion(entries: entries)

    await deletion.delete(try anExpense())

    // Offering to undo something that is still there would put the user one tap from an error.
    #expect(deletion.undoable == nil)
    #expect(deletion.failed)
}

@MainActor
@Test("A failed undo is reported rather than swallowed")
func aFailedUndoIsReported() async throws {
    let entries = RecordingEntryRepository(failOn: .restore)
    let deletion = MovementDeletion(entries: entries)
    await deletion.delete(try anExpense())

    await deletion.undo()

    #expect(deletion.failed)
}
