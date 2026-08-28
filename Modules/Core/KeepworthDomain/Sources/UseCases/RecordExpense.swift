/// Records an expense: money leaves an account and is charged to an expense category.
///
/// The user enters "42.30 on Groceries from BBVA" and this turns it into the two-line
/// entry. The UI never composes lines by hand.
public struct RecordExpense: Sendable {
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.entries = entries
    }

    public struct Request: Hashable, Sendable {
        /// The movement being rewritten, or `nil` for a new one. The editor corrects a
        /// movement by sending the same request it would send to create it, carrying the id
        /// of the one on screen.
        public let id: EntryID?
        public let accountID: AccountID
        public let categoryID: AccountID
        /// How much was spent, positive.
        public let amount: Money
        public let occurredOn: CalendarDate
        public let payee: String?
        public let note: String?

        public init(
            id: EntryID? = nil,
            accountID: AccountID,
            categoryID: AccountID,
            amount: Money,
            occurredOn: CalendarDate,
            payee: String? = nil,
            note: String? = nil
        ) {
            self.id = id
            self.accountID = accountID
            self.categoryID = categoryID
            self.amount = amount
            self.occurredOn = occurredOn
            self.payee = payee
            self.note = note
        }
    }

    @discardableResult
    public func execute(_ request: Request) async throws -> Entry {
        let account = try await accounts.account(withID: request.accountID)
        let category = try await accounts.account(withID: request.categoryID)

        try validateHoldsMoney(account)
        try validateIsCategory(category, ofKind: .expense)
        try validateMovement(of: request.amount, outOf: account, into: category)

        let entry = try Entry.twoLine(
            id: request.id ?? EntryID(),
            occurredOn: request.occurredOn,
            payee: request.payee,
            note: request.note,
            outOf: account.id,
            into: category.id,
            amount: request.amount
        )
        try await entries.save(entry)
        return entry
    }
}
