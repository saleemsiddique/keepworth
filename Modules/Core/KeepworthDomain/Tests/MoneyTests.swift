import Testing

@testable import KeepworthDomain

@Test("Sumar dos importes de la misma divisa da la suma de sus unidades menores")
func addsAmountsOfTheSameCurrency() throws {
    let total = try Money(minorUnits: 4230, currency: .eur) + Money(minorUnits: 770, currency: .eur)

    #expect(total == Money(minorUnits: 5000, currency: .eur))
}

@Test("Sumar importes de divisas distintas falla en vez de aproximar")
func rejectsAdditionBetweenDifferentCurrencies() {
    #expect(throws: MoneyError.currencyMismatch(expected: .eur, found: .usd)) {
        try Money(minorUnits: 100, currency: .eur) + Money(minorUnits: 100, currency: .usd)
    }
}

@Test("Restar importes de divisas distintas falla en vez de aproximar")
func rejectsSubtractionBetweenDifferentCurrencies() {
    #expect(throws: MoneyError.currencyMismatch(expected: .eur, found: .gbp)) {
        try Money(minorUnits: 100, currency: .eur) - Money(minorUnits: 100, currency: .gbp)
    }
}

@Test("Restar da la diferencia, con signo")
func subtractsAmounts() throws {
    let difference =
        try Money(minorUnits: 100, currency: .eur)
        - Money(minorUnits: 250, currency: .eur)

    #expect(difference == Money(minorUnits: -150, currency: .eur))
}

@Test("Un desbordamiento de Int64 falla en vez de dar la vuelta al signo")
func rejectsOverflow() {
    #expect(throws: MoneyError.amountOverflow) {
        try Money(minorUnits: .max, currency: .eur) + Money(minorUnits: 1, currency: .eur)
    }
}

@Test("La suma de una colección vacía es cero en la divisa indicada")
func sumsEmptyCollectionToZero() throws {
    #expect(try Money.sum([], in: .eur) == Money.zero(in: .eur))
}

@Test("La suma de una colección acumula todas sus unidades menores")
func sumsCollection() throws {
    let amounts = [
        Money(minorUnits: -4230, currency: .eur),
        Money(minorUnits: 4230, currency: .eur),
        Money(minorUnits: 1000, currency: .eur),
    ]

    #expect(try Money.sum(amounts, in: .eur) == Money(minorUnits: 1000, currency: .eur))
}

@Test("Negar un importe conserva la divisa y cambia el signo")
func negatesKeepingCurrency() throws {
    let negated = try Money(minorUnits: 4230, currency: .eur).negated()

    #expect(negated == Money(minorUnits: -4230, currency: .eur))
}

@Test("Negar el importe más pequeño posible falla en vez de abortar el proceso")
func rejectsNegatingTheSmallestAmount() {
    // -Int64.min no cabe en Int64. Negarlo directamente sería un trap, no un error, y el
    // dato puede venir de un CSV importado, no solo del teclado del usuario.
    #expect(throws: MoneyError.amountOverflow) {
        try Money(minorUnits: .min, currency: .eur).negated()
    }
}

@Test("Diez céntimos sumados diez veces son exactamente un euro")
func addsTenCentsTenTimesExactly() throws {
    let tenCents = Money(minorUnits: 10, currency: .eur)

    let total = try Money.sum(Array(repeating: tenCents, count: 10), in: .eur)

    // El mismo cálculo con Double da 0,9999999999999999.
    #expect(total == Money(minorUnits: 100, currency: .eur))
}
