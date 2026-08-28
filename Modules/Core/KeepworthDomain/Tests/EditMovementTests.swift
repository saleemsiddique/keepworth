import Testing

@testable import KeepworthDomain

/// Correcting a movement is recording it again over its own id. These fix the part that is
/// easy to get wrong: an edit that adds a second movement instead of replacing the first, or
/// that leaves the legs of the version being replaced behind.

@Test("Correcting an expense rewrites it instead of recording a second one")
func editingAnExpenseKeepsOneMovement() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let useCase = RecordExpense(accounts: ledger.accounts, entries: entries)

    let original = try await useCase.execute(
        RecordExpense.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.groceries.id,
            amount: euros(4230),
            occurredOn: try day(2026, 1, 31),
            payee: "Mercadona"
        )
    )

    let corrected = try await useCase.execute(
        RecordExpense.Request(
            id: original.id,
            accountID: ledger.checking.id,
            categoryID: ledger.rent.id,
            amount: euros(80000),
            occurredOn: try day(2026, 2, 1),
            payee: "Alquiler"
        )
    )

    #expect(corrected.id == original.id)
    #expect(await entries.savedEntries.count == 1)
    #expect(await entries.savedEntries.first?.payee == "Alquiler")
    #expect(await entries.savedEntries.first?.lines.count == 2)
}

@Test("A movement corrected into another type keeps its id and stays two-legged")
func editingAcrossTypesKeepsTwoLines() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let expense = RecordExpense(accounts: ledger.accounts, entries: entries)
    let transfer = TransferBetweenAccounts(accounts: ledger.accounts, entries: entries)

    // What the user does when they realise the money did not leave: it moved to their card.
    let recorded = try await expense.execute(
        RecordExpense.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.groceries.id,
            amount: euros(4230),
            occurredOn: try day(2026, 1, 31)
        )
    )

    let corrected = try await transfer.execute(
        TransferBetweenAccounts.Request(
            id: recorded.id,
            sourceAccountID: ledger.checking.id,
            destinationAccountID: ledger.cash.id,
            amount: euros(4230),
            occurredOn: try day(2026, 1, 31)
        )
    )

    #expect(corrected.id == recorded.id)
    #expect(corrected.lines.count == 2)
    #expect(await entries.savedEntries.count == 1)
    #expect(
        await entries.savedEntries.first?.lines.map(\.accountID).contains(ledger.groceries.id)
            == false)
}

@Test("Income is corrected over its own id too")
func editingIncomeKeepsOneMovement() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let useCase = RecordIncome(accounts: ledger.accounts, entries: entries)

    let original = try await useCase.execute(
        RecordIncome.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.salary.id,
            amount: euros(210_000),
            occurredOn: try day(2026, 1, 25)
        )
    )

    let corrected = try await useCase.execute(
        RecordIncome.Request(
            id: original.id,
            accountID: ledger.checking.id,
            categoryID: ledger.salary.id,
            amount: euros(215_000),
            occurredOn: try day(2026, 1, 25)
        )
    )

    #expect(corrected.id == original.id)
    #expect(await entries.savedEntries.count == 1)
    #expect(
        await entries.savedEntries.first?
            .lines.first(where: { $0.accountID == ledger.checking.id })?.amount == euros(215_000)
    )
}

@Test("A request with no id records a new movement")
func recordingWithoutIdAddsAMovement() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let useCase = RecordExpense(accounts: ledger.accounts, entries: entries)

    let first = try await useCase.execute(
        RecordExpense.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.groceries.id,
            amount: euros(4230),
            occurredOn: try day(2026, 1, 31)
        )
    )
    let second = try await useCase.execute(
        RecordExpense.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.groceries.id,
            amount: euros(4230),
            occurredOn: try day(2026, 1, 31)
        )
    )

    #expect(first.id != second.id)
    #expect(await entries.savedEntries.count == 2)
}
