/// An amount in whole minor units of a currency. €42.30 is `Money(4230, .eur)`.
///
/// Never a `Double`: binary floating point cannot represent 0.10, so ten cents added ten
/// times leaves a remainder that unbalances entries.
public struct Money: Hashable, Sendable {
    public let minorUnits: Int64
    public let currency: CurrencyCode

    public init(minorUnits: Int64, currency: CurrencyCode) {
        self.minorUnits = minorUnits
        self.currency = currency
    }

    public static func zero(in currency: CurrencyCode) -> Money {
        Money(minorUnits: 0, currency: currency)
    }

    public var isZero: Bool { minorUnits == 0 }
    public var isNegative: Bool { minorUnits < 0 }
    public var isPositive: Bool { minorUnits > 0 }

    /// Throws rather than negating directly: `-Int64.min` traps, and amounts can come from
    /// an imported CSV rather than the keyboard.
    public func negated() throws -> Money {
        try Money.zero(in: currency) - self
    }

    public static func + (lhs: Money, rhs: Money) throws -> Money {
        try lhs.combined(with: rhs) { $0.addingReportingOverflow($1) }
    }

    public static func - (lhs: Money, rhs: Money) throws -> Money {
        try lhs.combined(with: rhs) { $0.subtractingReportingOverflow($1) }
    }

    /// Takes the currency explicitly because an empty sequence sums to zero, and zero
    /// without a currency is not an amount.
    public static func sum(
        _ amounts: some Sequence<Money>,
        in currency: CurrencyCode
    ) throws -> Money {
        try amounts.reduce(Money.zero(in: currency)) { try $0 + $1 }
    }

    private func combined(
        with other: Money,
        using operation: (Int64, Int64) -> (partialValue: Int64, overflow: Bool)
    ) throws -> Money {
        guard currency == other.currency else {
            throw MoneyError.currencyMismatch(expected: currency, found: other.currency)
        }
        let result = operation(minorUnits, other.minorUnits)
        guard !result.overflow else {
            throw MoneyError.amountOverflow
        }
        return Money(minorUnits: result.partialValue, currency: currency)
    }
}

public enum MoneyError: Error, Equatable {
    /// Mixing currencies without an explicit exchange rate. Approximating would unbalance
    /// entries, so this fails instead.
    case currencyMismatch(expected: CurrencyCode, found: CurrencyCode)
    case amountOverflow
}
