/// Divisa según ISO 4217: tres letras mayúsculas.
///
/// El usuario elige una al empezar y todas sus cuentas la comparten. El tipo existe
/// desde el día uno aunque la v1 sea monodivisa: es lo que permite activar multi-divisa
/// más adelante sin migrar datos ni reescribir consultas.
public struct CurrencyCode: Hashable, Sendable, CustomStringConvertible {
    public let value: String

    public init(_ value: String) throws {
        guard Self.isValidCode(value) else {
            throw CurrencyCodeError.malformedCode(value)
        }
        self.value = value
    }

    /// Solo para las constantes de este archivo, cuyo valor es correcto por construcción.
    private init(validated value: String) {
        self.value = value
    }

    public var description: String { value }

    /// Cuántos dígitos decimales tiene la divisa: 2 significa que la unidad menor es el céntimo.
    ///
    /// En v1 todas las divisas asumen 2 porque la app es monodivisa y el usuario elige entre
    /// divisas de dos decimales. El yen tiene 0 y el bitcóin 8, así que al abrir multi-divisa
    /// esto pasa a depender de `value`: es el único punto del dominio que habrá que tocar.
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
    /// El código no son tres letras ASCII mayúsculas.
    case malformedCode(String)
}
