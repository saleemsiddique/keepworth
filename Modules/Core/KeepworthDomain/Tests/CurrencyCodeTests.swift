import Testing

@testable import KeepworthDomain

@Test("A valid ISO 4217 code is accepted")
func acceptsValidIsoCode() throws {
    #expect(try CurrencyCode("EUR").value == "EUR")
}

@Test(
    "A malformed code is rejected",
    arguments: ["eur", "EU", "EURO", "E1R", "", "€€€"]
)
func rejectsMalformedCode(code: String) {
    #expect(throws: CurrencyCodeError.malformedCode(code)) {
        try CurrencyCode(code)
    }
}

@Test("v1 currencies have two decimals")
func usesTwoDecimalsInFirstVersion() {
    #expect(CurrencyCode.eur.minorUnitExponent == 2)
}
