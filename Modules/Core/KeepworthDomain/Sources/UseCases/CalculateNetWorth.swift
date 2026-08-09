/// Net worth at a date: what you own minus what you owe.
///
/// **Asset and liability accounts only.** A category reaching this sum would tell the user
/// they have money they do not have.
///
/// The date filter is not optional: a future-dated movement is a forecast, and until its
/// day arrives the money is still where it was.
public struct CalculateNetWorth: Sendable {
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.entries = entries
    }

    /// - Parameters:
    ///   - date: last day that counts. Anything after has not happened yet.
    ///   - baseCurrency: the user's currency, the one every entry balances in.
    public func execute(
        asOf date: CalendarDate, in baseCurrency: CurrencyCode
    ) async throws -> Money {
        let netWorthAccounts = try await accounts.accounts(ofKinds: [.asset, .liability])
        guard !netWorthAccounts.isEmpty else {
            return .zero(in: baseCurrency)
        }

        let lines = try await entries.lines(
            matching: EntryLineQuery(
                accountIDs: Set(netWorthAccounts.map(\.id)),
                through: date
            )
        )
        return try Money.sum(lines.map(\.baseAmount), in: baseCurrency)
    }
}
