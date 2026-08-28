/// Opens a new place to hold money, with the balance it already had.
///
/// The starting balance is part of creating an account and not a separate step the screen
/// has to remember: an account added with the €20,000 already in it is the normal case, and
/// leaving it at zero would make the user record a fake income to fix it — which would then
/// show up in the period report as money earned this month.
///
/// Categories are not created here. They are accounts too, but they are listed apart and
/// never mixed with places holding money, so they get their own door when they get a screen.
public struct CreateAccount: Sendable {
    private let accounts: any AccountRepository
    private let openingBalance: SetOpeningBalance

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.openingBalance = SetOpeningBalance(accounts: accounts, entries: entries)
    }

    public struct Request: Hashable, Sendable {
        public let name: String
        public let kind: AccountKind
        public let institutionID: InstitutionID?
        public let currency: CurrencyCode
        /// SF Symbol name.
        public let symbolName: String?
        /// What the account already held. `nil` for a brand-new one starting at zero, and
        /// negative for a card carrying debt.
        public let startingBalance: Money?
        /// The day the starting balance was true. Only read when there is one.
        public let asOf: CalendarDate

        public init(
            name: String,
            kind: AccountKind,
            institutionID: InstitutionID? = nil,
            currency: CurrencyCode,
            symbolName: String? = nil,
            startingBalance: Money? = nil,
            asOf: CalendarDate
        ) {
            self.name = name
            self.kind = kind
            self.institutionID = institutionID
            self.currency = currency
            self.symbolName = symbolName
            self.startingBalance = startingBalance
            self.asOf = asOf
        }
    }

    @discardableResult
    public func execute(_ request: Request) async throws -> Account {
        guard request.kind.holdsMoney else {
            throw AccountError.kindCannotHoldMoney(request.kind)
        }

        let account = try Account(
            institutionID: request.institutionID,
            name: request.name,
            kind: request.kind,
            currency: request.currency,
            symbolName: request.symbolName
        )
        try await accounts.save(account)

        // Zero is not an opening balance, it is the absence of one, and `SetOpeningBalance`
        // rejects it rather than writing an entry that moves nothing.
        if let balance = request.startingBalance, !balance.isZero {
            try await openingBalance.execute(
                SetOpeningBalance.Request(
                    accountID: account.id,
                    balance: balance,
                    occurredOn: request.asOf
                )
            )
        }
        return account
    }
}
