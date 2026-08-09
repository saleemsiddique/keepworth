/// An account's balance at a date, in that account's currency.
///
/// A query, not a stored column: storing it would let the balance and the movements drift
/// apart. On an expense or income account this is not a balance but how much went through
/// it.
public struct CalculateAccountBalance: Sendable {
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.entries = entries
    }

    public func execute(accountID: AccountID, asOf date: CalendarDate) async throws -> Money {
        let account = try await accounts.account(withID: accountID)

        let lines = try await entries.lines(
            matching: EntryLineQuery(accountIDs: [accountID], through: date)
        )
        return try Money.sum(lines.map(\.amount), in: account.currency)
    }
}
