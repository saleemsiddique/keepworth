/// What you hold at a bank: the sum of its accounts in base currency.
///
/// A bank holds no money and receives no movements; it only groups accounts. This total
/// exists because a flat list stops working past six or seven accounts.
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
        // Fetched even though the name is unused: without this, a missing bank would total
        // zero and look no different from an empty one.
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
