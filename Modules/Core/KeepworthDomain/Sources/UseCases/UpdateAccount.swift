/// Corrects what an account is called, which bank it sits in and how it is drawn.
///
/// Neither its kind nor its currency: an account that has been an asset and becomes a
/// liability makes every figure already computed from it a lie, and there is no migration
/// from one to the other that would not need re-reading the whole history.
public struct UpdateAccount: Sendable {
    private let accounts: any AccountRepository

    public init(accounts: any AccountRepository) {
        self.accounts = accounts
    }

    public struct Request: Hashable, Sendable {
        public let accountID: AccountID
        public let name: String
        public let institutionID: InstitutionID?
        /// SF Symbol name.
        public let symbolName: String?

        public init(
            accountID: AccountID,
            name: String,
            institutionID: InstitutionID? = nil,
            symbolName: String? = nil
        ) {
            self.accountID = accountID
            self.name = name
            self.institutionID = institutionID
            self.symbolName = symbolName
        }
    }

    @discardableResult
    public func execute(_ request: Request) async throws -> Account {
        let stored = try await accounts.account(withID: request.accountID)
        try validateIsNotSystem(stored)

        let updated = try Account(
            id: stored.id,
            institutionID: request.institutionID,
            name: request.name,
            kind: stored.kind,
            currency: stored.currency,
            symbolName: request.symbolName,
            isSystem: stored.isSystem,
            isArchived: stored.isArchived
        )
        try await accounts.save(updated)
        return updated
    }
}
