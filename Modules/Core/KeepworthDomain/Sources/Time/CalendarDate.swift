/// Una fecha del calendario sin hora ni zona horaria: «31 de enero de 2026» y nada más.
///
/// No es un instante. Un movimiento registrado el 31 de enero sigue siendo del 31 de enero
/// se mire desde donde se mire, así que nunca cambia de mes en el informe ni discrepa entre
/// dos dispositivos sincronizados. Un `Date` sí cambiaría: es un punto en el tiempo, y el día
/// que representa depende de la zona con la que se lea.
///
/// La zona horaria interviene en un único sitio: al calcular qué día es **hoy** para fechar
/// un movimiento nuevo, lo que ocurre en la UI. A partir de ahí el dato queda congelado.
public struct CalendarDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) throws {
        guard (1...9999).contains(year) else {
            throw CalendarDateError.yearOutOfRange(year)
        }
        guard (1...12).contains(month) else {
            throw CalendarDateError.monthOutOfRange(month)
        }
        guard (1...Self.daysInMonth(month, ofYear: year)).contains(day) else {
            throw CalendarDateError.dayOutOfRange(day, month: month, year: year)
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Lee una fecha en formato ISO 8601 `yyyy-MM-dd`, que es como se guarda en la base de datos.
    public init(iso8601 text: String) throws {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
            parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else {
            throw CalendarDateError.malformedText(text)
        }
        try self.init(year: year, month: month, day: day)
    }

    /// Forma ISO 8601 `yyyy-MM-dd`. Coincide con la columna `TEXT` del esquema, y ordenarla
    /// como cadena da el mismo resultado que ordenarla como fecha.
    public var description: String {
        "\(Self.padded(year, toWidth: 4))-\(Self.padded(month, toWidth: 2))-\(Self.padded(day, toWidth: 2))"
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    static func daysInMonth(_ month: Int, ofYear year: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: 31
        case 4, 6, 9, 11: 30
        case 2: isLeapYear(year) ? 29 : 28
        default: 0
        }
    }

    /// Regla gregoriana completa: 2000 fue bisiesto y 1900 no lo fue.
    static func isLeapYear(_ year: Int) -> Bool {
        if year % 400 == 0 { return true }
        if year % 100 == 0 { return false }
        return year % 4 == 0
    }

    private static func padded(_ number: Int, toWidth width: Int) -> String {
        let digits = String(number)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}

public enum CalendarDateError: Error, Equatable {
    case yearOutOfRange(Int)
    case monthOutOfRange(Int)
    case dayOutOfRange(Int, month: Int, year: Int)
    /// El texto no tiene la forma `yyyy-MM-dd`.
    case malformedText(String)
}
