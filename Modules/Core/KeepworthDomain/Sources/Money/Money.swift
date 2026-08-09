/// Un importe: unidades menores enteras y la divisa a la que pertenecen.
///
/// 42,30 € son `Money(minorUnits: 4230, currency: .eur)`. **Nunca un `Double`**: los
/// binarios de coma flotante no representan 0,10 exactamente, así que sumar diez veces
/// diez céntimos deja un resto que descuadra los asientos.
///
/// Operar entre divisas distintas lanza error en lugar de aproximar. Convertir es una
/// decisión con un tipo de cambio detrás, no algo que un operador deba hacer solo.
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

    /// El mismo importe con el signo cambiado.
    ///
    /// Lanza en lugar de negar directamente porque `-Int64.min` no cabe en `Int64` y aborta
    /// el proceso. El importe es irreal, pero la entrada no siempre la escribe el usuario:
    /// el import de CSV la trae de un archivo externo, y ahí un dato absurdo tiene que dar
    /// un error, no tumbar la app.
    public func negated() throws -> Money {
        try Money.zero(in: currency) - self
    }

    public static func + (lhs: Money, rhs: Money) throws -> Money {
        try lhs.combined(with: rhs) { $0.addingReportingOverflow($1) }
    }

    public static func - (lhs: Money, rhs: Money) throws -> Money {
        try lhs.combined(with: rhs) { $0.subtractingReportingOverflow($1) }
    }

    /// Suma una colección de importes, que deben compartir divisa.
    ///
    /// Recibe la divisa explícitamente porque una colección vacía suma cero, y cero
    /// sin divisa no es un importe.
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
    /// Se intentó operar entre dos divisas distintas sin un tipo de cambio explícito.
    case currencyMismatch(expected: CurrencyCode, found: CurrencyCode)
    /// El resultado no cabe en `Int64`. Con céntimos son 92 billones de euros: el dato de
    /// entrada está mal, y fallar aquí es mejor que guardar un importe con el signo cambiado.
    case amountOverflow
}
