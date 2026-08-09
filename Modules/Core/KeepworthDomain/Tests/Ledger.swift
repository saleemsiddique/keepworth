@testable import KeepworthDomain

/// Un juego de cuentas y categorías de ejemplo, para que cada test hable de BBVA y de la
/// nómina en vez de montar seis cuentas antes de llegar a lo que comprueba.
struct Ledger {
    let bbva: Institution
    let checking: Account
    let creditCard: Account
    let cash: Account
    let groceries: Account
    let rent: Account
    let salary: Account
    /// La cuenta interna contra la que cuadran los saldos de partida. La crea la semilla del
    /// primer arranque en la app real.
    let openingBalance: Account

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
    }

    var accounts: InMemoryAccountRepository {
        InMemoryAccountRepository([
            checking, creditCard, cash, groceries, rent, salary, openingBalance,
        ])
    }

    var institutions: InMemoryInstitutionRepository {
        InMemoryInstitutionRepository([bbva])
    }
}

func euros(_ minorUnits: Int64) -> Money {
    Money(minorUnits: minorUnits, currency: .eur)
}

func day(_ year: Int, _ month: Int, _ day: Int) throws -> CalendarDate {
    try CalendarDate(year: year, month: month, day: day)
}
