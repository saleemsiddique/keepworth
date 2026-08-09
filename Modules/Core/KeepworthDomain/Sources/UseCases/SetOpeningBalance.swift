/// Gives an account the balance it already had when the user started using the app.
///
/// Its counterpart is the internal `equity` account, not an income category, which is what
/// keeps a starting balance out of the period report: you did not earn €20,000, you already
/// had it.
///
/// Accepts a negative balance — the normal case for a credit card carrying debt — so it
/// does not reuse the positive-amount rule the other movements share.
public struct SetOpeningBalance: Sendable {
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.entries = entries
    }

    public struct Request: Hashable, Sendable {
        public let accountID: AccountID
        /// The balance the account already had. Negative if it is a debt.
        public let balance: Money
        public let occurredOn: CalendarDate

        public init(accountID: AccountID, balance: Money, occurredOn: CalendarDate) {
            self.accountID = accountID
            self.balance = balance
            self.occurredOn = occurredOn
        }
    }

    @discardableResult
    public func execute(_ request: Request) async throws -> Entry {
        let account = try await accounts.account(withID: request.accountID)
        let openingBalanceAccount = try await systemOpeningBalanceAccount()

        try validateHoldsMoney(account)
        guard !account.isArchived else {
            throw MovementError.archivedAccount(account.id)
        }
        guard request.balance.currency == account.currency else {
            throw MovementError.currencyMismatch(
                expected: account.currency,
                found: request.balance.currency
            )
        }
        guard !request.balance.isZero else {
            throw MovementError.openingBalanceMustNotBeZero
        }

        // A positive balance flows into the account, a negative one out of it. Either way
        // the counterpart is the opening balance account and the entry balances.
        let entry =
            request.balance.isPositive
            ? try Entry.twoLine(
                occurredOn: request.occurredOn,
                payee: nil,
                note: nil,
                outOf: openingBalanceAccount.id,
                into: account.id,
                amount: request.balance
            )
            : try Entry.twoLine(
                occurredOn: request.occurredOn,
                payee: nil,
                note: nil,
                outOf: account.id,
                into: openingBalanceAccount.id,
                amount: try request.balance.negated()
            )
        try await entries.save(entry)
        return entry
    }

    private func systemOpeningBalanceAccount() async throws -> Account {
        let equityAccounts = try await accounts.accounts(ofKinds: [.equity])
        guard let openingBalance = equityAccounts.first(where: \.isSystem) else {
            throw MovementError.missingOpeningBalanceAccount
        }
        return openingBalance
    }
}
