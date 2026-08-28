import Testing

@testable import KeepworthDomain

/// Creating, correcting and archiving the places money sits in — what Settings reaches.

@Test("A new account starts with the balance it already had")
func createsAccountWithStartingBalance() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let useCase = CreateAccount(accounts: ledger.accounts, entries: entries)
    let balance = CalculateAccountBalance(accounts: ledger.accounts, entries: entries)

    let account = try await useCase.execute(
        CreateAccount.Request(
            name: "Remunerada",
            kind: .asset,
            institutionID: ledger.bbva.id,
            currency: .eur,
            startingBalance: euros(2_050_000),
            asOf: try day(2026, 1, 1)
        )
    )

    #expect(account.institutionID == ledger.bbva.id)
    #expect(
        try await balance.execute(accountID: account.id, asOf: try day(2026, 1, 31))
            == euros(2_050_000)
    )
}

@Test("A card is created carrying the debt it already had")
func createsLiabilityWithNegativeStartingBalance() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let useCase = CreateAccount(accounts: ledger.accounts, entries: entries)
    let balance = CalculateAccountBalance(accounts: ledger.accounts, entries: entries)

    let card = try await useCase.execute(
        CreateAccount.Request(
            name: "Visa Oro",
            kind: .liability,
            currency: .eur,
            startingBalance: euros(-32045),
            asOf: try day(2026, 1, 1)
        )
    )

    #expect(
        try await balance.execute(accountID: card.id, asOf: try day(2026, 1, 31)) == euros(-32045)
    )
}

@Test("A starting balance is not income: it stays out of the period report")
func startingBalanceStaysOutOfTheReport() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let useCase = CreateAccount(accounts: ledger.accounts, entries: entries)

    try await useCase.execute(
        CreateAccount.Request(
            name: "Remunerada",
            kind: .asset,
            currency: .eur,
            startingBalance: euros(2_050_000),
            asOf: try day(2026, 1, 15)
        )
    )

    let summary = try await SummarizePeriod(accounts: ledger.accounts, entries: entries)
        .execute(from: try day(2026, 1, 1), through: try day(2026, 1, 31), in: .eur)

    #expect(summary.income.isEmpty)
    #expect(summary.totalIncome == euros(0))
    #expect(summary.openingBalances == euros(2_050_000))
}

@Test("An account created without a starting balance records no movement")
func createsAccountWithoutMovement() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()

    try await CreateAccount(accounts: ledger.accounts, entries: entries).execute(
        CreateAccount.Request(
            name: "Cartera",
            kind: .asset,
            currency: .eur,
            asOf: try day(2026, 1, 1)
        )
    )

    #expect(await entries.savedEntries.isEmpty)
}

@Test("A category cannot be created through the door meant for places holding money")
func rejectsCategoryAsAccount() async throws {
    let ledger = try Ledger()
    let useCase = CreateAccount(accounts: ledger.accounts, entries: InMemoryEntryRepository())

    await #expect(throws: AccountError.kindCannotHoldMoney(.expense)) {
        try await useCase.execute(
            CreateAccount.Request(
                name: "Gasolina",
                kind: .expense,
                currency: .eur,
                asOf: try day(2026, 1, 1)
            )
        )
    }
}

@Test("Renaming an account keeps its kind, its currency and its history")
func updatesAccountName() async throws {
    let ledger = try Ledger()
    let useCase = UpdateAccount(accounts: ledger.accounts)

    let updated = try await useCase.execute(
        UpdateAccount.Request(
            accountID: ledger.checking.id,
            name: "Cuenta principal",
            institutionID: ledger.bbva.id,
            symbolName: "banknote"
        )
    )

    #expect(updated.id == ledger.checking.id)
    #expect(updated.name == "Cuenta principal")
    #expect(updated.kind == .asset)
    #expect(updated.currency == .eur)
    #expect(updated.symbolName == "banknote")
}

@Test("The opening balance account cannot be renamed")
func rejectsRenamingTheSystemAccount() async throws {
    let ledger = try Ledger()

    await #expect(throws: AccountError.systemAccountCannotChange(ledger.openingBalance.id)) {
        try await UpdateAccount(accounts: ledger.accounts).execute(
            UpdateAccount.Request(accountID: ledger.openingBalance.id, name: "Lo que sea")
        )
    }
}

@Test("The opening balance account cannot be archived")
func rejectsArchivingTheSystemAccount() async throws {
    let ledger = try Ledger()

    await #expect(throws: AccountError.systemAccountCannotChange(ledger.openingBalance.id)) {
        try await ArchiveAccount(accounts: ledger.accounts).execute(ledger.openingBalance.id)
    }
}

@Test("Archiving an account is undoable")
func archivesAndUnarchivesAnAccount() async throws {
    let ledger = try Ledger()
    let useCase = ArchiveAccount(accounts: ledger.accounts)

    try await useCase.execute(ledger.cash.id)
    #expect(try await ledger.accounts.account(withID: ledger.cash.id).isArchived)

    try await useCase.unarchive(ledger.cash.id)
    #expect(try await ledger.accounts.account(withID: ledger.cash.id).isArchived == false)
}

@Test("An archived account keeps its balance: it left the editor, not the ledger")
func archivedAccountStillCounts() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    try await RecordExpense(accounts: ledger.accounts, entries: entries).execute(
        RecordExpense.Request(
            accountID: ledger.cash.id,
            categoryID: ledger.groceries.id,
            amount: euros(4230),
            occurredOn: try day(2026, 1, 10)
        )
    )

    try await ArchiveAccount(accounts: ledger.accounts).execute(ledger.cash.id)

    let balance = try await CalculateAccountBalance(accounts: ledger.accounts, entries: entries)
        .execute(accountID: ledger.cash.id, asOf: try day(2026, 1, 31))
    #expect(balance == euros(-4230))
}

@Test("An archived bank is undoable too")
func archivesAndUnarchivesABank() async throws {
    let ledger = try Ledger()

    try await ledger.institutions.archive(ledger.bbva.id)
    #expect(try await ledger.institutions.institution(withID: ledger.bbva.id).isArchived)

    try await ledger.institutions.unarchive(ledger.bbva.id)
    #expect(try await ledger.institutions.institution(withID: ledger.bbva.id).isArchived == false)
}
