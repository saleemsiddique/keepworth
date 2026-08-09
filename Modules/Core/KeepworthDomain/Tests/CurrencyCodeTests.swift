import Testing

@testable import KeepworthDomain

@Test("Un código ISO 4217 válido se acepta")
func acceptsValidIsoCode() throws {
    #expect(try CurrencyCode("EUR").value == "EUR")
}

@Test(
    "Un código mal formado se rechaza",
    arguments: ["eur", "EU", "EURO", "E1R", "", "€€€"]
)
func rejectsMalformedCode(code: String) {
    #expect(throws: CurrencyCodeError.malformedCode(code)) {
        try CurrencyCode(code)
    }
}

@Test("Las divisas de v1 tienen dos decimales")
func usesTwoDecimalsInFirstVersion() {
    #expect(CurrencyCode.eur.minorUnitExponent == 2)
}
