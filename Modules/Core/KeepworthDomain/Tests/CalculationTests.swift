import Testing

@testable import KeepworthDomain

/// Opens the ledger with a starting balance, through the same path the app uses.
private func openingBalance(
    of amount: Money,
    in account: Account,
    on date: CalendarDate,
    of ledger: Ledger,
    into entries: InMemoryEntryRepository
) async throws {
    try await SetOpeningBalance(accounts: ledger.accounts, entries: entries).execute(
        SetOpeningBalance.Request(accountID: account.id, balance: amount, occurredOn: date)
    )
}

@Test("Net worth mixes assets and liabilities with the right sign")
func calculatesNetWorthMixingAssetsAndLiabilities() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    try await openingBalance(
        of: euros(200_000), in: ledger.checking, on: try day(2026, 1, 1), of: ledger, into: entries)
    // A card purchase: €600 of new debt.
    try await RecordExpense(accounts: ledger.accounts, entries: entries).execute(
        RecordExpense.Request(
            accountID: ledger.creditCard.id,
            categoryID: ledger.groceries.id,
            amount: euros(60000),
            occurredOn: try day(2026, 1, 10)
        )
    )

    let netWorth = try await CalculateNetWorth(accounts: ledger.accounts, entries: entries)
        .execute(asOf: try day(2026, 1, 31), in: .eur)

    #expect(netWorth == euros(140_000))
}

@Test("A future-dated movement does not count towards today's net worth")
func excludesFutureDatedEntriesFromNetWorth() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    try await openingBalance(
        of: euros(200_000), in: ledger.checking, on: try day(2026, 1, 1), of: ledger, into: entries)
    try await RecordExpense(accounts: ledger.accounts, entries: entries).execute(
        RecordExpense.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.rent.id,
            amount: euros(80000),
            occurredOn: try day(2026, 2, 1)
        )
    )

    let useCase = CalculateNetWorth(accounts: ledger.accounts, entries: entries)

    #expect(try await useCase.execute(asOf: try day(2026, 1, 31), in: .eur) == euros(200_000))
    #expect(try await useCase.execute(asOf: try day(2026, 2, 1), in: .eur) == euros(120_000))
}

@Test("Net worth does not move when a category is created, renamed or archived")
func netWorthIgnoresCategoryChanges() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    try await openingBalance(
        of: euros(200_000), in: ledger.checking, on: try day(2026, 1, 1), of: ledger, into: entries)
    try await RecordExpense(accounts: ledger.accounts, entries: entries).execute(
        RecordExpense.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.groceries.id,
            amount: euros(4230),
            occurredOn: try day(2026, 1, 10)
        )
    )
    let asOf = try day(2026, 1, 31)

    let before = try await CalculateNetWorth(accounts: ledger.accounts, entries: entries)
        .execute(asOf: asOf, in: .eur)

    let withNewCategory = ledger.accounts.adding(
        try Account(name: "Restaurantes", kind: .expense, currency: .eur)
    )
    let withRenamedCategory = withNewCategory.replacing(
        try Account(
            id: ledger.groceries.id,
            name: "Compra semanal",
            kind: .expense,
            currency: .eur
        )
    )
    let withArchivedCategory = withRenamedCategory.replacing(
        try Account(
            id: ledger.rent.id, name: "Vivienda", kind: .expense, currency: .eur, isArchived: true)
    )

    let after = try await CalculateNetWorth(accounts: withArchivedCategory, entries: entries)
        .execute(asOf: asOf, in: .eur)

    #expect(before == euros(195_770))
    #expect(after == before)
}

@Test("A transfer between accounts leaves net worth unchanged")
func transferLeavesNetWorthUnchanged() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    try await openingBalance(
        of: euros(200_000), in: ledger.checking, on: try day(2026, 1, 1), of: ledger, into: entries)
    let useCase = CalculateNetWorth(accounts: ledger.accounts, entries: entries)
    let asOf = try day(2026, 1, 31)
    let before = try await useCase.execute(asOf: asOf, in: .eur)

    try await TransferBetweenAccounts(accounts: ledger.accounts, entries: entries).execute(
        TransferBetweenAccounts.Request(
            sourceAccountID: ledger.checking.id,
            destinationAccountID: ledger.cash.id,
            amount: euros(50000),
            occurredOn: try day(2026, 1, 15)
        )
    )

    #expect(try await useCase.execute(asOf: asOf, in: .eur) == before)
}

@Test("An account balance is the sum of its lines, in its own currency")
func calculatesAccountBalance() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    try await openingBalance(
        of: euros(200_000), in: ledger.checking, on: try day(2026, 1, 1), of: ledger, into: entries)
    try await RecordExpense(accounts: ledger.accounts, entries: entries).execute(
        RecordExpense.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.groceries.id,
            amount: euros(4230),
            occurredOn: try day(2026, 1, 10)
        )
    )

    let balance = try await CalculateAccountBalance(accounts: ledger.accounts, entries: entries)
        .execute(accountID: ledger.checking.id, asOf: try day(2026, 1, 31))

    #expect(balance == euros(195_770))
}

@Test("A bank total sums only its own accounts")
func calculatesInstitutionTotal() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    try await openingBalance(
        of: euros(200_000), in: ledger.checking, on: try day(2026, 1, 1), of: ledger, into: entries)
    // Cash belongs to no bank, so it must stay out of the BBVA total.
    try await openingBalance(
        of: euros(10000), in: ledger.cash, on: try day(2026, 1, 1), of: ledger, into: entries)

    let total = try await CalculateInstitutionTotal(
        institutions: ledger.institutions,
        accounts: ledger.accounts,
        entries: entries
    ).execute(institutionID: ledger.bbva.id, asOf: try day(2026, 1, 31), in: .eur)

    #expect(total == euros(200_000))
}

@Test("The report separates income from expenses and orders them largest first")
func summarizesPeriodByCategory() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    let expense = RecordExpense(accounts: ledger.accounts, entries: entries)
    try await RecordIncome(accounts: ledger.accounts, entries: entries).execute(
        RecordIncome.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.salary.id,
            amount: euros(210_000),
            occurredOn: try day(2026, 1, 25)
        )
    )
    try await expense.execute(
        RecordExpense.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.rent.id,
            amount: euros(80000),
            occurredOn: try day(2026, 1, 3)
        )
    )
    try await expense.execute(
        RecordExpense.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.groceries.id,
            amount: euros(4230),
            occurredOn: try day(2026, 1, 10)
        )
    )

    let summary = try await SummarizePeriod(accounts: ledger.accounts, entries: entries)
        .execute(from: try day(2026, 1, 1), through: try day(2026, 1, 31), in: .eur)

    #expect(summary.totalIncome == euros(210_000))
    #expect(summary.totalExpenses == euros(84230))
    #expect(summary.expenses.map(\.total) == [euros(80000), euros(4230)])
    #expect(summary.income == [AccountTotal(accountID: ledger.salary.id, total: euros(210_000))])
}

@Test("A transfer does not appear in the period report")
func summaryIgnoresTransfers() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    try await TransferBetweenAccounts(accounts: ledger.accounts, entries: entries).execute(
        TransferBetweenAccounts.Request(
            sourceAccountID: ledger.checking.id,
            destinationAccountID: ledger.cash.id,
            amount: euros(50000),
            occurredOn: try day(2026, 1, 15)
        )
    )

    let summary = try await SummarizePeriod(accounts: ledger.accounts, entries: entries)
        .execute(from: try day(2026, 1, 1), through: try day(2026, 1, 31), in: .eur)

    #expect(summary.expenses.isEmpty)
    #expect(summary.income.isEmpty)
    #expect(summary.saved == Money.zero(in: .eur))
}

@Test("What was saved in the month is exactly what net worth moved")
func savedInPeriodMatchesNetWorthChange() async throws {
    // The guarantee that justifies double entry: the report and net worth are two readings
    // of the same lines, so they cannot disagree by a cent.
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    try await openingBalance(
        of: euros(500_000), in: ledger.checking, on: try day(2025, 12, 31), of: ledger,
        into: entries)
    let expense = RecordExpense(accounts: ledger.accounts, entries: entries)
    try await RecordIncome(accounts: ledger.accounts, entries: entries).execute(
        RecordIncome.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.salary.id,
            amount: euros(210_000),
            occurredOn: try day(2026, 1, 25)
        )
    )
    try await expense.execute(
        RecordExpense.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.rent.id,
            amount: euros(80000),
            occurredOn: try day(2026, 1, 3)
        )
    )
    try await expense.execute(
        RecordExpense.Request(
            accountID: ledger.creditCard.id,
            categoryID: ledger.groceries.id,
            amount: euros(4230),
            occurredOn: try day(2026, 1, 10)
        )
    )
    // A transfer, which must not move either side of the equality.
    try await TransferBetweenAccounts(accounts: ledger.accounts, entries: entries).execute(
        TransferBetweenAccounts.Request(
            sourceAccountID: ledger.checking.id,
            destinationAccountID: ledger.cash.id,
            amount: euros(30000),
            occurredOn: try day(2026, 1, 20)
        )
    )

    let netWorth = CalculateNetWorth(accounts: ledger.accounts, entries: entries)
    let atStart = try await netWorth.execute(asOf: try day(2025, 12, 31), in: .eur)
    let atEnd = try await netWorth.execute(asOf: try day(2026, 1, 31), in: .eur)
    let change = try atEnd - atStart

    let summary = try await SummarizePeriod(accounts: ledger.accounts, entries: entries)
        .execute(from: try day(2026, 1, 1), through: try day(2026, 1, 31), in: .eur)

    #expect(summary.netWorthChange == change)
    #expect(summary.saved == euros(125_770))
    // In a month with no new accounts, saved and the net worth delta are the same.
    #expect(summary.openingBalances == Money.zero(in: .eur))
    #expect(summary.netWorthChange == summary.saved)
}

@Test("Creating an account mid-month does not put the report at odds with net worth")
func netWorthChangeAbsorbsOpeningBalancesInsidePeriod() async throws {
    // A starting balance raises net worth without being income: that money was already
    // yours. If the report ignored it, its figures and net worth would disagree in the very
    // month an account is created, and that would read as a bug.
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    try await openingBalance(
        of: euros(500_000),
        in: ledger.checking,
        on: try day(2025, 12, 31),
        of: ledger,
        into: entries
    )
    // A new account declared inside the period.
    try await openingBalance(
        of: euros(75000),
        in: ledger.cash,
        on: try day(2026, 1, 12),
        of: ledger,
        into: entries
    )
    try await RecordExpense(accounts: ledger.accounts, entries: entries).execute(
        RecordExpense.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.rent.id,
            amount: euros(80000),
            occurredOn: try day(2026, 1, 3)
        )
    )

    let netWorth = CalculateNetWorth(accounts: ledger.accounts, entries: entries)
    let change =
        try await netWorth.execute(asOf: try day(2026, 1, 31), in: .eur)
        - netWorth.execute(asOf: try day(2025, 12, 31), in: .eur)

    let summary = try await SummarizePeriod(accounts: ledger.accounts, entries: entries)
        .execute(from: try day(2026, 1, 1), through: try day(2026, 1, 31), in: .eur)

    #expect(summary.saved == euros(-80000))
    #expect(summary.openingBalances == euros(75000))
    #expect(summary.netWorthChange == euros(-5000))
    #expect(summary.netWorthChange == change)
}

@Test("An account can open with a negative balance, like a card carrying debt")
func acceptsNegativeOpeningBalance() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()

    try await openingBalance(
        of: euros(-60000),
        in: ledger.creditCard,
        on: try day(2026, 1, 1),
        of: ledger,
        into: entries
    )

    let netWorth = try await CalculateNetWorth(accounts: ledger.accounts, entries: entries)
        .execute(asOf: try day(2026, 1, 31), in: .eur)

    #expect(netWorth == euros(-60000))
}

@Test("A zero opening balance is rejected")
func rejectsZeroOpeningBalance() async throws {
    let ledger = try Ledger()
    let useCase = SetOpeningBalance(
        accounts: ledger.accounts,
        entries: InMemoryEntryRepository()
    )

    await #expect(throws: MovementError.openingBalanceMustNotBeZero) {
        try await useCase.execute(
            SetOpeningBalance.Request(
                accountID: ledger.checking.id,
                balance: Money.zero(in: .eur),
                occurredOn: try day(2026, 1, 1)
            )
        )
    }
}

@Test("An opening balance on a category is rejected")
func rejectsOpeningBalanceOnCategory() async throws {
    let ledger = try Ledger()
    let useCase = SetOpeningBalance(
        accounts: ledger.accounts,
        entries: InMemoryEntryRepository()
    )

    await #expect(throws: MovementError.accountCannotHoldMoney(.expense)) {
        try await useCase.execute(
            SetOpeningBalance.Request(
                accountID: ledger.groceries.id,
                balance: euros(1000),
                occurredOn: try day(2026, 1, 1)
            )
        )
    }
}

@Test("Without the internal opening balance account, the use case fails instead of inventing one")
func rejectsOpeningBalanceWithoutSystemAccount() async throws {
    let ledger = try Ledger()
    let withoutEquity = InMemoryAccountRepository([ledger.checking, ledger.groceries])
    let useCase = SetOpeningBalance(accounts: withoutEquity, entries: InMemoryEntryRepository())

    await #expect(throws: MovementError.missingOpeningBalanceAccount) {
        try await useCase.execute(
            SetOpeningBalance.Request(
                accountID: ledger.checking.id,
                balance: euros(1000),
                occurredOn: try day(2026, 1, 1)
            )
        )
    }
}

@Test("An opening balance does not show up as income in the report")
func openingBalanceDoesNotContaminateTheReport() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()

    try await openingBalance(
        of: euros(500_000),
        in: ledger.checking,
        on: try day(2026, 1, 5),
        of: ledger,
        into: entries
    )

    let summary = try await SummarizePeriod(accounts: ledger.accounts, entries: entries)
        .execute(from: try day(2026, 1, 1), through: try day(2026, 1, 31), in: .eur)

    #expect(summary.income.isEmpty)
    #expect(summary.totalIncome == Money.zero(in: .eur))
    #expect(summary.openingBalances == euros(500_000))
}
