import Foundation
import GRDB
import KeepworthDomain
import Testing

@testable import KeepworthPersistence

/// A clock the test moves by hand, for the cases that need to control `created_at` exactly.
/// The default `StoredLedger` clock is a constant, which is what lets the other tests assert
/// on timestamps instead of racing it.
private final class MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = StoredLedger.creationDate

    func set(_ date: Date) {
        lock.lock()
        defer { lock.unlock() }
        current = date
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }
}

/// Builds a ledger with three expenses on three different days, newest last.
private func ledgerWithThreeExpenses() async throws -> (
    ledger: StoredLedger, cash: Account, groceries: Account, housing: Account
) {
    let ledger = try StoredLedger()
    try await ledger.seed()
    let cash = try await ledger.account(named: "Efectivo")
    let groceries = try await ledger.account(named: "Supermercado")
    let housing = try await ledger.account(named: "Vivienda")

    let expense = RecordExpense(accounts: ledger.accounts, entries: ledger.entries)
    for (dayOfMonth, category, payee) in [
        (10, groceries, "Mercadona"),
        (20, housing, "Alquiler"),
        (30, groceries, "Consum"),
    ] {
        _ = try await expense.execute(
            RecordExpense.Request(
                accountID: cash.id,
                categoryID: category.id,
                amount: euros(1000),
                occurredOn: try day(2026, 1, dayOfMonth),
                payee: payee
            )
        )
    }

    return (ledger, cash, groceries, housing)
}

@Test("Entries come back newest first")
func entriesComeBackNewestFirst() async throws {
    let (ledger, _, _, _) = try await ledgerWithThreeExpenses()

    let entries = try await ledger.entries.entries(matching: try EntryQuery(limit: 10))

    #expect(entries.map(\.payee) == ["Consum", "Alquiler", "Mercadona"])
}

@Test("The limit caps how many come back, keeping the newest")
func limitKeepsTheNewest() async throws {
    let (ledger, _, _, _) = try await ledgerWithThreeExpenses()

    let entries = try await ledger.entries.entries(matching: try EntryQuery(limit: 2))

    #expect(entries.map(\.payee) == ["Consum", "Alquiler"])
}

@Test("A read entry carries every line, not only the ones the filter matched")
func readEntryCarriesEveryLine() async throws {
    let (ledger, cash, groceries, _) = try await ledgerWithThreeExpenses()

    // Filtering by the category alone. Each of these entries also has a leg on cash, and
    // without it `Entry.init` would reject the entry for not summing to zero.
    let entries = try await ledger.entries.entries(
        matching: try EntryQuery(accountIDs: [groceries.id], limit: 10)
    )

    #expect(entries.count == 2)
    // Two legs each: the category the filter matched, and the cash it came out of. Asserting
    // the residual is zero would be decorative — `Entry.init` already refused to build one
    // that was not, so the objects existing is the proof.
    #expect(entries.allSatisfy { $0.lines.count == 2 })
    #expect(entries.allSatisfy { entry in entry.lines.contains { $0.accountID == cash.id } })
}

@Test("Filtering by account returns only the movements that touch it")
func filteringByAccountNarrowsTheList() async throws {
    let (ledger, _, _, housing) = try await ledgerWithThreeExpenses()

    let entries = try await ledger.entries.entries(
        matching: try EntryQuery(accountIDs: [housing.id], limit: 10)
    )

    #expect(entries.map(\.payee) == ["Alquiler"])
}

@Test("The date range includes both of its ends")
func dateRangeIncludesBothEnds() async throws {
    let (ledger, _, _, _) = try await ledgerWithThreeExpenses()

    // Pinned on the outermost movements on purpose. A range that cleared them by a few days
    // would pass just the same with `>` and `<` instead of `>=` and `<=`, and that is the bug
    // that drops the first and last day of every monthly report.
    let entries = try await ledger.entries.entries(
        matching: try EntryQuery(
            from: try day(2026, 1, 10),
            through: try day(2026, 1, 30),
            limit: 10
        )
    )

    #expect(entries.map(\.payee) == ["Consum", "Alquiler", "Mercadona"])
}

@Test("The date range excludes what falls outside it")
func dateRangeExcludesTheRest() async throws {
    let (ledger, _, _, _) = try await ledgerWithThreeExpenses()

    let entries = try await ledger.entries.entries(
        matching: try EntryQuery(
            from: try day(2026, 1, 15),
            through: try day(2026, 1, 25),
            limit: 10
        )
    )

    #expect(entries.map(\.payee) == ["Alquiler"])
}

@Test("A deleted entry disappears from the list")
func deletedEntryDisappears() async throws {
    let (ledger, _, _, housing) = try await ledgerWithThreeExpenses()
    let target = try await ledger.entries.entries(
        matching: try EntryQuery(accountIDs: [housing.id], limit: 1)
    )[0]

    // Written by hand because no deletion API exists yet; it arrives with the screen that
    // asks for it. What is being proved is that the read honours the tombstone.
    try await ledger.database.writer.write { db in
        try db.execute(
            sql: "UPDATE entry SET deleted_at = ? WHERE id = ?",
            arguments: [StoredLedger.creationDate, target.id.rawValue.uuidString]
        )
    }

    let entries = try await ledger.entries.entries(matching: try EntryQuery(limit: 10))
    #expect(entries.map(\.payee) == ["Consum", "Mercadona"])
}

@Test("An entry whose stored lines no longer balance is rejected on read")
func unbalancedStoredEntryIsRejectedOnRead() async throws {
    let (ledger, _, _, housing) = try await ledgerWithThreeExpenses()
    let target = try await ledger.entries.entries(
        matching: try EntryQuery(accountIDs: [housing.id], limit: 1)
    )[0]

    // Corrupting one leg on purpose. This is what would happen if a sync applied half an
    // entry, and the point of reading through `Entry.init` is that it surfaces instead of
    // being drawn on screen as a movement that does not add up.
    try await ledger.database.writer.write { db in
        try db.execute(
            sql: """
                UPDATE entry_line SET base_amount_minor = base_amount_minor + 1
                WHERE entry_id = ? AND amount_minor < 0
                """,
            arguments: [target.id.rawValue.uuidString]
        )
    }

    // The concrete case, not `EntryError.self`: that would also swallow
    // `needsAtLeastTwoLines`, which is what a broken line query would raise — so the test
    // would stay green while proving the opposite of what it claims.
    await #expect(throws: EntryError.unbalanced(residual: euros(1))) {
        try await ledger.entries.entries(matching: try EntryQuery(limit: 10))
    }
}

@Test("Movements of the same day come back newest created first")
func sameDayEntriesAreOrderedByCreationTime() async throws {
    let clock = MutableClock()
    let ledger = try StoredLedger(now: clock.now)
    try await ledger.seed()
    let cash = try await ledger.account(named: "Efectivo")
    let groceries = try await ledger.account(named: "Supermercado")
    let sameDay = try day(2026, 1, 15)
    let expense = RecordExpense(accounts: ledger.accounts, entries: ledger.entries)

    // Inserted in the opposite order to their creation, which is what sync does when a device
    // receives an entry made earlier somewhere else. It matters that they disagree: with an
    // index on `occurred_on`, SQLite walks it backwards and hands back reverse insertion
    // order, which happens to equal `created_at DESC` whenever the two agree. This is the only
    // arrangement where dropping the tie-break shows up.
    for (payee, secondsLater) in [("Creado después", 300.0), ("Creado antes", 100.0)] {
        clock.set(StoredLedger.creationDate.addingTimeInterval(secondsLater))
        _ = try await expense.execute(
            RecordExpense.Request(
                accountID: cash.id,
                categoryID: groceries.id,
                amount: euros(1000),
                occurredOn: sameDay,
                payee: payee
            )
        )
    }

    let entries = try await ledger.entries.entries(matching: try EntryQuery(limit: 10))

    #expect(entries.map(\.payee) == ["Creado después", "Creado antes"])
}

@Test("An entry moved to another category stops matching the old one")
func movingCategoryStopsMatchingTheOldOne() async throws {
    let (ledger, cash, groceries, housing) = try await ledgerWithThreeExpenses()
    let target = try await ledger.entries.entries(
        matching: try EntryQuery(accountIDs: [housing.id], limit: 1)
    )[0]

    // Re-saving with a different category buries the old line. If the account filter went
    // against `entry_line` instead of `live_entry_line`, that buried line would keep the
    // entry matching a category it no longer has.
    try await ledger.entries.save(
        try Entry(
            id: target.id,
            occurredOn: target.occurredOn,
            payee: target.payee,
            lines: [
                EntryLine(accountID: cash.id, amount: euros(-1000)),
                EntryLine(accountID: groceries.id, amount: euros(1000)),
            ]
        )
    )

    let stillHousing = try await ledger.entries.entries(
        matching: try EntryQuery(accountIDs: [housing.id], limit: 10)
    )
    #expect(stillHousing.isEmpty)

    let nowGroceries = try await ledger.entries.entries(
        matching: try EntryQuery(accountIDs: [groceries.id], limit: 10)
    )
    #expect(nowGroceries.count == 3)
}

@Test("A re-saved entry is read once, not twice")
func reSavedEntryIsReadOnce() async throws {
    let (ledger, cash, groceries, _) = try await ledgerWithThreeExpenses()
    let original = try await ledger.entries.entries(matching: try EntryQuery(limit: 1))[0]

    let edited = try Entry(
        id: original.id,
        occurredOn: original.occurredOn,
        payee: "Consum Express",
        lines: [
            EntryLine(accountID: cash.id, amount: euros(-2500)),
            EntryLine(accountID: groceries.id, amount: euros(2500)),
        ]
    )
    try await ledger.entries.save(edited)

    let entries = try await ledger.entries.entries(matching: try EntryQuery(limit: 10))
    #expect(entries.count == 3)
    #expect(entries[0].payee == "Consum Express")
    #expect(entries[0].lines.count == 2)
}

@Test("Asking for an empty set of accounts returns nothing")
func emptyAccountSetReturnsNothing() async throws {
    let (ledger, _, _, _) = try await ledgerWithThreeExpenses()

    let entries = try await ledger.entries.entries(
        matching: try EntryQuery(accountIDs: [], limit: 10)
    )

    #expect(entries.isEmpty)
}
