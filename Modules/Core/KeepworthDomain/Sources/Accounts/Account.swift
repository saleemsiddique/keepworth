/// Un sitio donde el dinero entra o del que sale.
///
/// Cuentas y categorías comparten tipo a propósito: es lo que hace que registrar un gasto,
/// un ingreso o un traspaso sea exactamente la misma operación. Lo que las diferencia es
/// el `kind`, y la UI nunca las mezcla en la misma lista.
public struct Account: Hashable, Sendable, Identifiable {
    public let id: AccountID
    /// El banco al que pertenece. `nil` en efectivo y en toda categoría.
    public let institutionID: InstitutionID?
    public let name: String
    public let kind: AccountKind
    public let currency: CurrencyCode
    /// Nombre de SF Symbol con el que la UI la representa.
    public let symbolName: String?
    /// Cierto solo en «Saldo inicial»: ni se borra ni se renombra, porque es lo que hace
    /// que los números cuadren.
    public let isSystem: Bool
    /// Una cuenta archivada desaparece del editor pero sigue en el histórico. Es lo que se
    /// hace en vez de borrar cuando ya tiene movimientos, que si no quedarían huérfanos.
    public let isArchived: Bool

    public init(
        id: AccountID = AccountID(),
        institutionID: InstitutionID? = nil,
        name: String,
        kind: AccountKind,
        currency: CurrencyCode,
        symbolName: String? = nil,
        isSystem: Bool = false,
        isArchived: Bool = false
    ) throws {
        let trimmedName = name.trimmedForStorage
        guard !trimmedName.isEmpty else {
            throw AccountError.blankName
        }
        if institutionID != nil && !kind.canBelongToInstitution {
            throw AccountError.kindCannotBelongToInstitution(kind)
        }
        self.id = id
        self.institutionID = institutionID
        self.name = trimmedName
        self.kind = kind
        self.currency = currency
        self.symbolName = symbolName?.trimmedForStorageOrNil
        self.isSystem = isSystem
        self.isArchived = isArchived
    }

    /// Si su saldo forma parte del patrimonio neto.
    public var countsTowardsNetWorth: Bool { kind.countsTowardsNetWorth }
}

public enum AccountError: Error, Equatable {
    /// Una cuenta sin nombre no se puede elegir en un selector.
    case blankName
    /// Se intentó meter una categoría o el saldo inicial dentro de un banco. Un banco agrupa
    /// sitios donde hay dinero, y una categoría no lo es.
    case kindCannotBelongToInstitution(AccountKind)
}
