import Testing

@testable import KeepworthDomain

/// Arranca el libro con un saldo inicial en una cuenta, por el mismo camino que la app.
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

@Test("El patrimonio mezcla activo y pasivo con el signo correcto")
func calculatesNetWorthMixingAssetsAndLiabilities() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    try await openingBalance(
        of: euros(200_000), in: ledger.checking, on: try day(2026, 1, 1), of: ledger, into: entries)
    // Una compra con tarjeta: 600 € de deuda nueva.
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

@Test("Un movimiento fechado en el futuro no cuenta en el patrimonio de hoy")
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

@Test("El patrimonio no varía al crear, renombrar ni archivar una categoría")
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

@Test("Un traspaso entre cuentas no mueve el patrimonio")
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

@Test("El saldo de una cuenta es la suma de sus líneas, en su divisa")
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

@Test("El total de un banco suma solo sus cuentas")
func calculatesInstitutionTotal() async throws {
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    try await openingBalance(
        of: euros(200_000), in: ledger.checking, on: try day(2026, 1, 1), of: ledger, into: entries)
    // El efectivo no está en ningún banco: no debe entrar en el total del BBVA.
    try await openingBalance(
        of: euros(10000), in: ledger.cash, on: try day(2026, 1, 1), of: ledger, into: entries)

    let total = try await CalculateInstitutionTotal(
        institutions: ledger.institutions,
        accounts: ledger.accounts,
        entries: entries
    ).execute(institutionID: ledger.bbva.id, asOf: try day(2026, 1, 31), in: .eur)

    #expect(total == euros(200_000))
}

@Test("El informe separa ingresos de gastos y los ordena de mayor a menor")
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

@Test("Un traspaso no aparece en el informe del periodo")
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

@Test("Lo ahorrado en el mes es exactamente lo que varió el patrimonio")
func savedInPeriodMatchesNetWorthChange() async throws {
    // Es la garantía que justifica la partida doble: el informe y el patrimonio son dos
    // lecturas de las mismas líneas, así que no pueden contradecirse ni por un céntimo.
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
    // Un traspaso, que no debe alterar ninguno de los dos lados de la igualdad.
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
    // En un mes sin cuentas nuevas, lo ahorrado y la variación del patrimonio son lo mismo.
    #expect(summary.openingBalances == Money.zero(in: .eur))
    #expect(summary.netWorthChange == summary.saved)
}

@Test("Crear una cuenta a mitad de mes no descuadra el informe con el patrimonio")
func netWorthChangeAbsorbsOpeningBalancesInsidePeriod() async throws {
    // El saldo de partida sube el patrimonio sin ser un ingreso: ese dinero ya era tuyo.
    // Si el informe lo ignorase, sus cifras y el patrimonio discreparían justo el mes en que
    // el usuario da de alta una cuenta, y parecería un bug en vez de contabilidad correcta.
    let ledger = try Ledger()
    let entries = InMemoryEntryRepository()
    try await openingBalance(
        of: euros(500_000),
        in: ledger.checking,
        on: try day(2025, 12, 31),
        of: ledger,
        into: entries
    )
    // Una cuenta nueva declarada dentro del periodo.
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

@Test("Una cuenta puede empezar con saldo negativo, como una tarjeta con deuda")
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

@Test("Un saldo inicial de cero se rechaza")
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

@Test("Un saldo inicial sobre una categoría se rechaza")
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

@Test("Sin la cuenta interna de saldo inicial, el caso de uso falla en vez de inventarla")
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

@Test("El saldo inicial no aparece como ingreso en el informe")
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
