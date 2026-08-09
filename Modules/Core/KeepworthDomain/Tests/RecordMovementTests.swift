import Testing

@testable import KeepworthDomain

@Test("Un gasto sale de la cuenta y entra en la categoría, por el mismo importe")
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

@Test("Un ingreso entra en la cuenta y sale de la categoría de ingreso")
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

@Test("Un gasto con una categoría de ingreso se rechaza")
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

@Test("Un gasto cuya «cuenta» es en realidad una categoría se rechaza")
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

@Test("Un importe cero o negativo se rechaza", arguments: [Int64(0), -1, -4230])
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

@Test("Una cuenta archivada no admite movimientos nuevos")
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

@Test("Un traspaso a la misma cuenta se rechaza")
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

@Test("Un traspaso contra una categoría se rechaza")
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

@Test("Una cuenta que no existe se propaga como error, no como movimiento a medias")
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

@Test("Un movimiento rechazado no deja nada guardado")
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

@Test("Pagar con tarjeta de crédito aumenta la deuda y baja el patrimonio")
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

    // El saldo de la tarjeta se hace más negativo: eso es más deuda.
    #expect(
        entry.lines.first(where: { $0.accountID == ledger.creditCard.id })?.amount == euros(-6000))
}
