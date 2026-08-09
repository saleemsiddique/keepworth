import Testing

@testable import KeepworthDomain

@Test("An expense leaves the account and enters the category for the same amount")
func recordsExpenseAsBalancedEntry() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let useCase = RecordExpense(accounts: ledger.accounts, entries: entries)

    let entry = try await useCase.execute(
        RecordExpense.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.groceries.id,
            amount: euros(4230),
            occurredOn: try day(2026, 1, 31),
            payee: "Mercadona"
        )
    )

    #expect(entry.lines.count == 2)
    #expect(entry.lines[0].accountID == ledger.checking.id)
    #expect(entry.lines[0].amount == euros(-4230))
    #expect(entry.lines[1].accountID == ledger.groceries.id)
    #expect(entry.lines[1].amount == euros(4230))
    #expect(await entries.savedEntries == [entry])
}

@Test("Income enters the account and leaves the income category")
func recordsIncomeAsBalancedEntry() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let useCase = RecordIncome(accounts: ledger.accounts, entries: entries)

    let entry = try await useCase.execute(
        RecordIncome.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.salary.id,
            amount: euros(210_000),
            occurredOn: try day(2026, 1, 25)
        )
    )

    #expect(
        entry.lines.first(where: { $0.accountID == ledger.checking.id })?.amount == euros(210_000))
    #expect(
        entry.lines.first(where: { $0.accountID == ledger.salary.id })?.amount == euros(-210_000))
}

@Test("An expense against an income category is rejected")
func rejectsExpenseAgainstIncomeCategory() async throws {
    let ledger = try Ledger()
    let useCase = RecordExpense(accounts: ledger.accounts, entries: InMemoryEntryRepository())

    await #expect(throws: MovementError.wrongCategoryKind(expected: .expense, found: .income)) {
        try await useCase.execute(
            RecordExpense.Request(
                accountID: ledger.checking.id,
                categoryID: ledger.salary.id,
                amount: euros(4230),
                occurredOn: try day(2026, 1, 31)
            )
        )
    }
}

@Test("An expense whose account is really a category is rejected")
func rejectsExpenseFromCategory() async throws {
    let ledger = try Ledger()
    let useCase = RecordExpense(accounts: ledger.accounts, entries: InMemoryEntryRepository())

    await #expect(throws: MovementError.accountCannotHoldMoney(.expense)) {
        try await useCase.execute(
            RecordExpense.Request(
                accountID: ledger.rent.id,
                categoryID: ledger.groceries.id,
                amount: euros(4230),
                occurredOn: try day(2026, 1, 31)
            )
        )
    }
}

@Test("A zero or negative amount is rejected", arguments: [Int64(0), -1, -4230])
func rejectsNonPositiveAmount(minorUnits: Int64) async throws {
    let ledger = try Ledger()
    let useCase = RecordExpense(accounts: ledger.accounts, entries: InMemoryEntryRepository())

    await #expect(throws: MovementError.amountMustBePositive) {
        try await useCase.execute(
            RecordExpense.Request(
                accountID: ledger.checking.id,
                categoryID: ledger.groceries.id,
                amount: euros(minorUnits),
                occurredOn: try day(2026, 1, 31)
            )
        )
    }
}

@Test("An archived account takes no new movements")
func rejectsMovementIntoArchivedAccount() async throws {
    let ledger = try Ledger()
    let archived = try Account(
        id: ledger.cash.id,
        name: ledger.cash.name,
        kind: .asset,
        currency: .eur,
        isArchived: true
    )
    let accounts = ledger.accounts.replacing(archived)
    let useCase = RecordExpense(accounts: accounts, entries: InMemoryEntryRepository())

    await #expect(throws: MovementError.archivedAccount(archived.id)) {
        try await useCase.execute(
            RecordExpense.Request(
                accountID: archived.id,
                categoryID: ledger.groceries.id,
                amount: euros(4230),
                occurredOn: try day(2026, 1, 31)
            )
        )
    }
}

@Test("A transfer to the same account is rejected")
func rejectsTransferToTheSameAccount() async throws {
    let ledger = try Ledger()
    let useCase = TransferBetweenAccounts(
        accounts: ledger.accounts,
        entries: InMemoryEntryRepository()
    )

    await #expect(throws: MovementError.sameAccountOnBothSides(ledger.checking.id)) {
        try await useCase.execute(
            TransferBetweenAccounts.Request(
                sourceAccountID: ledger.checking.id,
                destinationAccountID: ledger.checking.id,
                amount: euros(50000),
                occurredOn: try day(2026, 1, 31)
            )
        )
    }
}

@Test("A transfer against a category is rejected")
func rejectsTransferAgainstCategory() async throws {
    let ledger = try Ledger()
    let useCase = TransferBetweenAccounts(
        accounts: ledger.accounts,
        entries: InMemoryEntryRepository()
    )

    await #expect(throws: MovementError.accountCannotHoldMoney(.expense)) {
        try await useCase.execute(
            TransferBetweenAccounts.Request(
                sourceAccountID: ledger.checking.id,
                destinationAccountID: ledger.groceries.id,
                amount: euros(50000),
                occurredOn: try day(2026, 1, 31)
            )
        )
    }
}

@Test("A missing account propagates as an error, not as a half-written movement")
func propagatesMissingAccount() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let unknown = AccountID()
    let useCase = RecordExpense(accounts: ledger.accounts, entries: entries)

    await #expect(throws: RepositoryError.accountNotFound(unknown)) {
        try await useCase.execute(
            RecordExpense.Request(
                accountID: unknown,
                categoryID: ledger.groceries.id,
                amount: euros(4230),
                occurredOn: try day(2026, 1, 31)
            )
        )
    }
    #expect(await entries.savedEntries.isEmpty)
}

@Test("A rejected movement saves nothing")
func savesNothingWhenValidationFails() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let useCase = RecordExpense(accounts: ledger.accounts, entries: entries)

    await #expect(throws: MovementError.amountMustBePositive) {
        try await useCase.execute(
            RecordExpense.Request(
                accountID: ledger.checking.id,
                categoryID: ledger.groceries.id,
                amount: euros(-100),
                occurredOn: try day(2026, 1, 31)
            )
        )
    }
    #expect(await entries.savedEntries.isEmpty)
}

@Test("Paying by credit card grows the debt and lowers net worth")
func recordsCreditCardPayment() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let useCase = RecordExpense(accounts: ledger.accounts, entries: entries)

    let entry = try await useCase.execute(
        RecordExpense.Request(
            accountID: ledger.creditCard.id,
            categoryID: ledger.groceries.id,
            amount: euros(6000),
            occurredOn: try day(2026, 1, 31)
        )
    )

    // The card's balance goes further negative: that is more debt.
    #expect(
        entry.lines.first(where: { $0.accountID == ledger.creditCard.id })?.amount == euros(-6000))
}
