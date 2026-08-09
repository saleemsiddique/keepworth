/// Lo que tienes en un banco: la suma de sus cuentas en divisa base.
///
/// Un banco no guarda dinero ni recibe movimientos; solo agrupa cuentas. Este total existe
/// porque con seis o siete cuentas una lista plana deja de servir.
public struct CalculateInstitutionTotal: Sendable {
    private let institutions: any InstitutionRepository
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(
        institutions: any InstitutionRepository,
        accounts: any AccountRepository,
        entries: any EntryRepository
    ) {
        self.institutions = institutions
        self.accounts = accounts
        self.entries = entries
    }

    public func execute(
        institutionID: InstitutionID,
        asOf date: CalendarDate,
        in baseCurrency: CurrencyCode
    ) async throws -> Money {
        // Se pide el banco aunque no se use su nombre: si no existe, el total sería cero y
        // el usuario no sabría distinguirlo de un banco vacío.
        _ = try await institutions.institution(withID: institutionID)

        let institutionAccounts = try await accounts.accounts(inInstitution: institutionID)
        guard !institutionAccounts.isEmpty else {
            return .zero(in: baseCurrency)
        }

        let lines = try await entries.lines(
            matching: EntryLineQuery(
                accountIDs: Set(institutionAccounts.map(\.id)),
                through: date
            )
        )
        return try Money.sum(lines.map(\.baseAmount), in: baseCurrency)
    }
}
