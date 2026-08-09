/// An ISO 4217 currency: three uppercase letters.
///
/// The user picks one and every account shares it. The type exists from day one even
/// though v1 is single-currency, so enabling multi-currency needs no data migration.
public struct CurrencyCode: Hashable, Sendable, CustomStringConvertible {
    public let value: String

    public init(_ value: String) throws {
        guard Self.isValidCode(value) else {
            throw CurrencyCodeError.malformedCode(value)
        }
        self.value = value
    }

    /// For the constants below, whose values are correct by construction.
    private init(validated value: String) {
        self.value = value
    }

    public var description: String { value }

    /// Decimal digits in the currency: 2 means the minor unit is the cent.
    ///
    /// Hardcoded for v1. The yen has 0 and bitcoin has 8, so this is the single place the
    /// domain changes when multi-currency opens.
    public var minorUnitExponent: Int { 2 }

    private static func isValidCode(_ value: String) -> Bool {
        value.count == 3 && value.allSatisfy { $0.isASCII && $0.isUppercase && $0.isLetter }
    }
}

extension CurrencyCode {
    public static let eur = CurrencyCode(validated: "EUR")
    public static let usd = CurrencyCode(validated: "USD")
    public static let gbp = CurrencyCode(validated: "GBP")
}

public enum CurrencyCodeError: Error, Equatable {
    case malformedCode(String)
}
