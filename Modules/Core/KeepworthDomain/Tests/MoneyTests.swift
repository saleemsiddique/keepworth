import Testing

@testable import KeepworthDomain

@Test("Adding two amounts of the same currency sums their minor units")
func addsAmountsOfTheSameCurrency() throws {
    let total = try Money(minorUnits: 4230, currency: .eur) + Money(minorUnits: 770, currency: .eur)

    #expect(total == Money(minorUnits: 5000, currency: .eur))
}

@Test("Adding amounts in different currencies fails instead of approximating")
func rejectsAdditionBetweenDifferentCurrencies() {
    #expect(throws: MoneyError.currencyMismatch(expected: .eur, found: .usd)) {
        try Money(minorUnits: 100, currency: .eur) + Money(minorUnits: 100, currency: .usd)
    }
}

@Test("Subtracting amounts in different currencies fails instead of approximating")
func rejectsSubtractionBetweenDifferentCurrencies() {
    #expect(throws: MoneyError.currencyMismatch(expected: .eur, found: .gbp)) {
        try Money(minorUnits: 100, currency: .eur) - Money(minorUnits: 100, currency: .gbp)
    }
}

@Test("Subtracting gives the signed difference")
func subtractsAmounts() throws {
    let difference =
        try Money(minorUnits: 100, currency: .eur)
        - Money(minorUnits: 250, currency: .eur)

    #expect(difference == Money(minorUnits: -150, currency: .eur))
}

@Test("An Int64 overflow fails instead of flipping the sign")
func rejectsOverflow() {
    #expect(throws: MoneyError.amountOverflow) {
        try Money(minorUnits: .max, currency: .eur) + Money(minorUnits: 1, currency: .eur)
    }
}

@Test("Summing an empty collection gives zero in the given currency")
func sumsEmptyCollectionToZero() throws {
    #expect(try Money.sum([], in: .eur) == Money.zero(in: .eur))
}

@Test("Summing a collection accumulates all its minor units")
func sumsCollection() throws {
    let amounts = [
        Money(minorUnits: -4230, currency: .eur),
        Money(minorUnits: 4230, currency: .eur),
        Money(minorUnits: 1000, currency: .eur),
    ]

    #expect(try Money.sum(amounts, in: .eur) == Money(minorUnits: 1000, currency: .eur))
}

@Test("Negating an amount keeps the currency and flips the sign")
func negatesKeepingCurrency() throws {
    let negated = try Money(minorUnits: 4230, currency: .eur).negated()

    #expect(negated == Money(minorUnits: -4230, currency: .eur))
}

@Test("Negating the smallest possible amount fails instead of trapping")
func rejectsNegatingTheSmallestAmount() {
    // -Int64.min does not fit in Int64. Negating directly would trap rather than throw,
    // and the value can come from an imported CSV, not only from the keyboard.
    #expect(throws: MoneyError.amountOverflow) {
        try Money(minorUnits: .min, currency: .eur).negated()
    }
}

@Test("Ten cents added ten times is exactly one euro")
func addsTenCentsTenTimesExactly() throws {
    let tenCents = Money(minorUnits: 10, currency: .eur)

    let total = try Money.sum(Array(repeating: tenCents, count: 10), in: .eur)

    // The same sum in Double gives 0.9999999999999999.
    #expect(total == Money(minorUnits: 100, currency: .eur))
}
