import Testing

@testable import KeepworthDomain

@Test("An asset account can belong to a bank")
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

@Test("A credit card can belong to a bank")
func allowsLiabilityInsideInstitution() throws {
    let bbva = try Institution(name: "BBVA")

    let card = try Account(institutionID: bbva.id, name: "Visa", kind: .liability, currency: .eur)

    #expect(card.institutionID == bbva.id)
}

@Test(
    "A category or the opening balance inside a bank is rejected",
    arguments: [AccountKind.expense, .income, .equity]
)
func rejectsNonMonetaryKindInsideInstitution(kind: AccountKind) throws {
    let bbva = try Institution(name: "BBVA")

    #expect(throws: AccountError.kindCannotBelongToInstitution(kind)) {
        try Account(institutionID: bbva.id, name: "Supermercado", kind: kind, currency: .eur)
    }
}

@Test("An account with a blank name is rejected", arguments: ["", "   ", "\n"])
func rejectsBlankName(name: String) {
    #expect(throws: AccountError.blankName) {
        try Account(name: name, kind: .asset, currency: .eur)
    }
}

@Test("A name is stored without surrounding whitespace")
func trimsName() throws {
    #expect(try Account(name: "  Efectivo  ", kind: .asset, currency: .eur).name == "Efectivo")
}

@Test("Only assets and liabilities count towards net worth")
func onlyAssetAndLiabilityCountTowardsNetWorth() {
    #expect(AccountKind.asset.countsTowardsNetWorth)
    #expect(AccountKind.liability.countsTowardsNetWorth)
    #expect(!AccountKind.expense.countsTowardsNetWorth)
    #expect(!AccountKind.income.countsTowardsNetWorth)
    #expect(!AccountKind.equity.countsTowardsNetWorth)
}

@Test("A bank with a blank name is rejected")
func rejectsBlankInstitutionName() {
    #expect(throws: InstitutionError.blankName) {
        try Institution(name: "  ")
    }
}
