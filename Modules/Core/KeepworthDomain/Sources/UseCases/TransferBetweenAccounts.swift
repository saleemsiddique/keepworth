/// Moves money between two of the user's accounts.
///
/// It stays out of the period report without needing to be excluded: both legs are money
/// accounts and the report only looks at categories. Net worth does not move either.
///
/// A transfer between banks takes days to land, but there is no bridge account: it applies
/// whole on its date, which is a detail the date already settles.
public struct TransferBetweenAccounts: Sendable {
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.entries = entries
    }

    public struct Request: Hashable, Sendable {
        public let sourceAccountID: AccountID
        public let destinationAccountID: AccountID
        /// How much is transferred, positive.
        public let amount: Money
        public let occurredOn: CalendarDate
        public let note: String?

        public init(
            sourceAccountID: AccountID,
            destinationAccountID: AccountID,
            amount: Money,
            occurredOn: CalendarDate,
            note: String? = nil
        ) {
            self.sourceAccountID = sourceAccountID
            self.destinationAccountID = destinationAccountID
            self.amount = amount
            self.occurredOn = occurredOn
            self.note = note
        }
    }

    @discardableResult
    public func execute(_ request: Request) async throws -> Entry {
        let source = try await accounts.account(withID: request.sourceAccountID)
        let destination = try await accounts.account(withID: request.destinationAccountID)

        try validateHoldsMoney(source)
        try validateHoldsMoney(destination)
        try validateMovement(of: request.amount, outOf: source, into: destination)

        let entry = try Entry.twoLine(
            occurredOn: request.occurredOn,
            payee: nil,
            note: request.note,
            outOf: source.id,
            into: destination.id,
            amount: request.amount
        )
        try await entries.save(entry)
        return entry
    }
}
