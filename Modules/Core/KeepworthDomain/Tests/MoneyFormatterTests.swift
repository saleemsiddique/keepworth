import Foundation
import Testing

@testable import KeepworthDomain

private let spain = Locale(identifier: "es_ES")
private let unitedStates = Locale(identifier: "en_US")

/// Compares ignoring which space character the formatter chose. Foundation uses a narrow
/// no-break space between the number and the symbol in some locales and a plain no-break
/// space in others, and it has changed across OS versions — pinning it would make these tests
/// fail on an upgrade over something no user can see.
private func hasSameText(_ produced: String, as expected: String) -> Bool {
    func normalised(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }
    return normalised(produced) == normalised(expected)
}

@Test("An amount takes the shape of the locale reading it")
func amountTakesTheShapeOfTheLocale() {
    // 24.560,80 €, the net worth of the mock in ESTADO §8.
    let netWorth = Money(minorUnits: 2_456_080, currency: .eur)

    #expect(hasSameText(MoneyFormatter(locale: spain).string(for: netWorth), as: "24.560,80 €"))
    #expect(
        hasSameText(
            MoneyFormatter(locale: unitedStates).string(for: netWorth),
            as: "€24,560.80"
        )
    )
}

@Test("A balance carries no sign unless it is negative")
func balanceCarriesNoSignUnlessNegative() {
    let formatter = MoneyFormatter(locale: spain)

    // Five figures on purpose: Spanish writes a four-digit number without the thousands
    // separator, so `1200,00 €` is correct there and would read as a missing separator.
    let balance = Money(minorUnits: 2_050_000, currency: .eur)
    #expect(hasSameText(formatter.string(for: balance), as: "20.500,00 €"))
    #expect(!formatter.string(for: balance).contains("+"))
    // A card with debt. The minus here says there is debt, not that money moved.
    #expect(formatter.string(for: Money(minorUnits: -32045, currency: .eur)).contains("-"))
}

@Test("An amount with direction always carries its sign")
func directedAmountAlwaysCarriesItsSign() {
    let formatter = MoneyFormatter(locale: spain)

    #expect(formatter.signedString(for: Money(minorUnits: 210_000, currency: .eur)).contains("+"))
    #expect(formatter.signedString(for: Money(minorUnits: -4230, currency: .eur)).contains("-"))
}

@Test("Zero takes no sign, even where one would be forced")
func zeroTakesNoSign() {
    let formatter = MoneyFormatter(locale: spain)
    let nothing = formatter.signedString(for: .zero(in: .eur))

    // `+0,00 €` would read as money that came in. Nothing came in.
    #expect(!nothing.contains("+"))
    #expect(!nothing.contains("-"))
}

@Test("The currency is the one the amount carries, not the one the locale prefers")
func currencyComesFromTheAmount() {
    let dollars = Money(minorUnits: 12345, currency: .usd)

    // Read in Spain, but the amount is in dollars: the locale decides the shape, the money
    // decides the currency. This is what keeps multi-currency reachable without a rewrite.
    let text = MoneyFormatter(locale: spain).string(for: dollars)
    #expect(text.contains("123,45"))
    #expect(!text.contains("€"))
}

@Test("Minor units never leak through as a floating point error")
func minorUnitsSurviveFormatting() {
    let formatter = MoneyFormatter(locale: spain)

    // 0,10 is the classic amount binary floating point cannot hold. Going through `Decimal`
    // rather than `Double` is what keeps this exact.
    for cents in Int64(1)...Int64(100) {
        let text = formatter.string(for: Money(minorUnits: cents, currency: .eur))
        #expect(text.contains(cents == 100 ? "1,00" : String(format: "0,%02d", cents)))
    }
}
