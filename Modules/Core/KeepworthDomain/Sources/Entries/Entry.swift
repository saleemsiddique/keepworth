/// Un movimiento completo, por partida doble: el dinero sale de un sitio y entra en otro.
///
/// Un gasto de 42,30 € no es «−42,30» suelto: son dos líneas, una que baja el saldo de la
/// cuenta y otra que lo imputa a una categoría. Por eso el informe del mes y la variación
/// del patrimonio no pueden contradecirse — son dos lecturas de las mismas líneas.
///
/// Construir un `Entry` es la única forma de crear un movimiento, y su inicializador rechaza
/// todo lo que no cuadre. Un asiento inválido no llega a existir.
public struct Entry: Hashable, Sendable, Identifiable {
    public let id: EntryID
    /// El día en que ocurrió. Un asiento con fecha futura no cuenta en el patrimonio hasta
    /// que llega ese día.
    public let occurredOn: CalendarDate
    /// A quién se le pagó o de quién se cobró: «Mercadona».
    public let payee: String?
    public let note: String?
    public let lines: [EntryLine]

    public init(
        id: EntryID = EntryID(),
        occurredOn: CalendarDate,
        payee: String? = nil,
        note: String? = nil,
        lines: [EntryLine]
    ) throws {
        guard lines.count >= 2 else {
            throw EntryError.needsAtLeastTwoLines(found: lines.count)
        }

        let baseCurrency = lines[0].baseAmount.currency
        guard lines.allSatisfy({ $0.baseAmount.currency == baseCurrency }) else {
            throw EntryError.mixedBaseCurrencies
        }

        let residual = try Money.sum(lines.map(\.baseAmount), in: baseCurrency)
        guard residual.isZero else {
            throw EntryError.unbalanced(residual: residual)
        }

        self.id = id
        self.occurredOn = occurredOn
        self.payee = payee?.trimmedForStorageOrNil
        self.note = note?.trimmedForStorageOrNil
        self.lines = lines
    }

    /// La divisa en la que cuadra el asiento: la del usuario.
    public var baseCurrency: CurrencyCode { lines[0].baseAmount.currency }
}

public enum EntryError: Error, Equatable {
    /// Un movimiento con una sola línea no es contabilidad, es un número suelto: no dice
    /// de dónde salió el dinero ni adónde fue.
    case needsAtLeastTwoLines(found: Int)
    /// Lo que sale y lo que entra no coinciden. `residual` es lo que sobra o falta.
    case unbalanced(residual: Money)
    /// Las líneas declaran divisas base distintas. La divisa base es la del usuario y es una
    /// sola: si dos líneas discrepan, el importe de alguna está mal calculado.
    case mixedBaseCurrencies
}
