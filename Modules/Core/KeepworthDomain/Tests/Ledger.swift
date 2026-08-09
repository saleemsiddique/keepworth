@testable import KeepworthDomain

/// Sample accounts and categories, so each test can talk about BBVA and payroll instead
/// of building six accounts before reaching what it checks.
struct Ledger {
    let bbva: Institution
    let checking: Account
    let creditCard: Account
    let cash: Account
    let groceries: Account
    let rent: Account
    let salary: Account
    /// The internal account starting balances balance against. The first-launch seed
    /// creates it in the real app.
    let openingBalance: Account
    /// One instance per ledger, not a fresh one per call: tests write to it now.
    let accounts: InMemoryAccountRepository
    let institutions: InMemoryInstitutionRepository

    init() throws {
        bbva = try Institution(name: "BBVA")
        checking = try Account(
            institutionID: bbva.id,
            name: "Nómina",
            kind: .asset,
            currency: .eur
        )
        creditCard = try Account(
            institutionID: bbva.id,
            name: "Visa",
            kind: .liability,
            currency: .eur
        )
        cash = try Account(name: "Efectivo", kind: .asset, currency: .eur)
        groceries = try Account(name: "Supermercado", kind: .expense, currency: .eur)
        rent = try Account(name: "Vivienda", kind: .expense, currency: .eur)
        salary = try Account(name: "Nómina", kind: .income, currency: .eur)
        openingBalance = try Account(
            name: "Saldo inicial",
            kind: .equity,
            currency: .eur,
            isSystem: true
        )
        accounts = InMemoryAccountRepository([
            checking, creditCard, cash, groceries, rent, salary, openingBalance,
        ])
        institutions = InMemoryInstitutionRepository([bbva])
    }
}

func euros(_ minorUnits: Int64) -> Money {
    Money(minorUnits: minorUnits, currency: .eur)
}

func day(_ year: Int, _ month: Int, _ day: Int) throws -> CalendarDate {
    try CalendarDate(year: year, month: month, day: day)
}
