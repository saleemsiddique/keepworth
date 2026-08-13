import Testing

@testable import KeepworthDomain

private let spanishNames = SeedFirstLaunch.Names(
    cash: "Efectivo",
    openingBalance: "Saldo inicial",
    expenseCategories: [
        "Supermercado", "Restaurantes", "Transporte", "Vivienda", "Suministros",
        "Salud", "Ocio", "Compras", "Suscripciones",
    ],
    incomeCategories: ["Nómina", "Intereses", "Otros ingresos"]
)

private func seededLedger() async throws -> (InMemoryAccountRepository, InMemorySettingsRepository)
{
    let accounts = InMemoryAccountRepository()
    let settings = InMemorySettingsRepository()
    try await SeedFirstLaunch(accounts: accounts, settings: settings)
        .execute(names: spanishNames, baseCurrency: .eur)
    return (accounts, settings)
}

@Test("The seed creates cash, the opening balance account and every category")
func seedsTheStartingLedger() async throws {
    let (accounts, _) = try await seededLedger()

    #expect(try await accounts.accounts(ofKinds: [.asset]).map(\.name) == ["Efectivo"])
    #expect(try await accounts.accounts(ofKinds: [.expense]).count == 9)
    #expect(try await accounts.accounts(ofKinds: [.income]).count == 3)
    #expect(try await accounts.accounts(ofKinds: [.liability]).isEmpty)
}

@Test("The opening balance account is the only system account, and it is equity")
func marksOnlyTheOpeningBalanceAsSystem() async throws {
    let (accounts, _) = try await seededLedger()

    let equity = try await accounts.accounts(ofKinds: [.equity])
    #expect(equity.count == 1)
    #expect(equity[0].name == "Saldo inicial")
    #expect(equity[0].isSystem)

    let everythingElse = try await accounts.accounts(ofKinds: [.asset, .expense, .income])
    #expect(everythingElse.allSatisfy { !$0.isSystem })
}

@Test("Every seeded account uses the currency the user picked")
func seedsInTheChosenCurrency() async throws {
    let accounts = InMemoryAccountRepository()
    let settings = InMemorySettingsRepository()

    try await SeedFirstLaunch(accounts: accounts, settings: settings)
        .execute(names: spanishNames, baseCurrency: .gbp)

    let everyKind = Set(AccountKind.allCases)
    #expect(try await accounts.accounts(ofKinds: everyKind).allSatisfy { $0.currency == .gbp })
    #expect(try await settings.baseCurrency() == .gbp)
}

@Test("No seeded account belongs to a bank: the user creates their banks")
func seedsNoInstitutions() async throws {
    let (accounts, _) = try await seededLedger()

    let everyKind = Set(AccountKind.allCases)
    #expect(try await accounts.accounts(ofKinds: everyKind).allSatisfy { $0.institutionID == nil })
}

@Test("Seeding a ledger that already has a currency is rejected")
func rejectsSeedingTwice() async throws {
    let (accounts, settings) = try await seededLedger()
    let useCase = SeedFirstLaunch(accounts: accounts, settings: settings)

    await #expect(throws: SeedError.alreadySeeded) {
        try await useCase.execute(names: spanishNames, baseCurrency: .eur)
    }
}

@Test("A seed without categories is rejected")
func rejectsSeedWithoutCategories() async throws {
    let accounts = InMemoryAccountRepository()
    let settings = InMemorySettingsRepository()
    let names = SeedFirstLaunch.Names(
        cash: "Efectivo",
        openingBalance: "Saldo inicial",
        expenseCategories: [],
        incomeCategories: ["Nómina"]
    )

    await #expect(throws: SeedError.noCategories) {
        try await SeedFirstLaunch(accounts: accounts, settings: settings)
            .execute(names: names, baseCurrency: .eur)
    }
    #expect(try await settings.baseCurrency() == nil)
}
