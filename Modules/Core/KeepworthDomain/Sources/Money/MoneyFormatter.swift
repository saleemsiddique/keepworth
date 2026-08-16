import Foundation

/// Turns `Money` into the text a screen shows.
///
/// It lives beside `Money` rather than in a presentation layer because the design system may
/// not see `Money` at all, and every feature would otherwise grow its own copy. How many
/// decimals a currency has is a fact about the currency, not about the screen.
///
/// **`Decimal` appears here and nowhere else in the domain, and only on the last step to
/// text.** Arithmetic stays in `Int64`: that is the whole reason entries can sum to exactly
/// zero. Formatting is the one place a decimal representation is not only safe but required,
/// because `NumberFormatter` speaks decimals.
public struct MoneyFormatter: Sendable {
    private let locale: Locale

    public init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    /// For balances and totals: a sign only when the amount is negative.
    ///
    /// A positive balance reads `20.500,00 €`. Prefixing it with `+` would suggest something
    /// moved, and a balance is a state.
    public func string(for money: Money) -> String {
        formatted(money, alwaysSigned: false)
    }

    /// For amounts that have a direction: always a `+` or a `−`.
    ///
    /// The sign is redundant with the colour on purpose — the figure has to survive being read
    /// in greyscale, by someone who cannot tell the two apart, or copied somewhere plain.
    public func signedString(for money: Money) -> String {
        formatted(money, alwaysSigned: true)
    }

    private func formatted(_ money: Money, alwaysSigned: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = money.currency.value

        let digits = money.currency.minorUnitExponent
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits

        if alwaysSigned, money.isPositive {
            formatter.positivePrefix = formatter.plusSign + formatter.positivePrefix
        }

        let amount = Decimal(money.minorUnits) / pow(10, digits)
        // The fallback is unreachable with a `.currency` formatter and a valid ISO code, but
        // returning it beats crashing a screen over a number that failed to render.
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
