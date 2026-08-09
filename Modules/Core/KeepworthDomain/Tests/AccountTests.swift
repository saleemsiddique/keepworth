import Testing

@testable import KeepworthDomain

@Test("Una cuenta de activo puede pertenecer a un banco")
func allowsAssetInsideInstitution() throws {
    let bbva = try Institution(name: "BBVA")

    let account = try Account(
        institutionID: bbva.id,
        name: "Nómina",
        kind: .asset,
        currency: .eur
    )

    #expect(account.institutionID == bbva.id)
}

@Test("Una tarjeta de crédito puede pertenecer a un banco")
func allowsLiabilityInsideInstitution() throws {
    let bbva = try Institution(name: "BBVA")

    let card = try Account(institutionID: bbva.id, name: "Visa", kind: .liability, currency: .eur)

    #expect(card.institutionID == bbva.id)
}

@Test(
    "Una categoría o el saldo inicial dentro de un banco se rechaza",
    arguments: [AccountKind.expense, .income, .equity]
)
func rejectsNonMonetaryKindInsideInstitution(kind: AccountKind) throws {
    let bbva = try Institution(name: "BBVA")

    #expect(throws: AccountError.kindCannotBelongToInstitution(kind)) {
        try Account(institutionID: bbva.id, name: "Supermercado", kind: kind, currency: .eur)
    }
}

@Test("Una cuenta sin nombre se rechaza", arguments: ["", "   ", "\n"])
func rejectsBlankName(name: String) {
    #expect(throws: AccountError.blankName) {
        try Account(name: name, kind: .asset, currency: .eur)
    }
}

@Test("El nombre se guarda sin espacios alrededor")
func trimsName() throws {
    #expect(try Account(name: "  Efectivo  ", kind: .asset, currency: .eur).name == "Efectivo")
}

@Test("Solo el activo y el pasivo cuentan para el patrimonio")
func onlyAssetAndLiabilityCountTowardsNetWorth() {
    #expect(AccountKind.asset.countsTowardsNetWorth)
    #expect(AccountKind.liability.countsTowardsNetWorth)
    #expect(!AccountKind.expense.countsTowardsNetWorth)
    #expect(!AccountKind.income.countsTowardsNetWorth)
    #expect(!AccountKind.equity.countsTowardsNetWorth)
}

@Test("Un banco sin nombre se rechaza")
func rejectsBlankInstitutionName() {
    #expect(throws: InstitutionError.blankName) {
        try Institution(name: "  ")
    }
}
