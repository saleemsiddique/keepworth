/// Un banco o entidad financiera: BBVA, Trade Republic, MyInvestor.
///
/// Agrupa cuentas y da un total por entidad. **No guarda dinero ni recibe movimientos**:
/// meterlo en `Account` obligaría a inventar una cuenta que no es una cuenta.
public struct Institution: Hashable, Sendable, Identifiable {
    public let id: InstitutionID
    public let name: String

    public init(id: InstitutionID = InstitutionID(), name: String) throws {
        let trimmedName = name.trimmedForStorage
        guard !trimmedName.isEmpty else {
            throw InstitutionError.blankName
        }
        self.id = id
        self.name = trimmedName
    }
}

public enum InstitutionError: Error, Equatable {
    /// Un banco sin nombre no se puede distinguir de otro en la lista.
    case blankName
}
