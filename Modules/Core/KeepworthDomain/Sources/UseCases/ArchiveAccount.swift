/// Takes an account out of the editor without taking it out of the ledger.
///
/// This is what happens instead of deleting: the money that went through it is still the
/// user's, so the summary keeps showing it and net worth keeps counting it. Hiding the row
/// while the bank total still included it would leave a figure on screen that does not add
/// up to the rows underneath it.
///
/// Two methods on one type rather than a boolean parameter, the same shape `DeleteMovement`
/// uses for its undo.
public struct ArchiveAccount: Sendable {
    private let accounts: any AccountRepository

    public init(accounts: any AccountRepository) {
        self.accounts = accounts
    }

    public func execute(_ id: AccountID) async throws {
        try validateIsNotSystem(try await accounts.account(withID: id))
        try await accounts.archive(id)
    }

    public func unarchive(_ id: AccountID) async throws {
        try validateIsNotSystem(try await accounts.account(withID: id))
        try await accounts.unarchive(id)
    }
}

/// "Opening balance" is what every starting balance is booked against. Renaming it would
/// show an internal name the user never chose, and archiving it would leave the next account
/// they add with nothing to balance against.
func validateIsNotSystem(_ account: Account) throws {
    guard !account.isSystem else {
        throw AccountError.systemAccountCannotChange(account.id)
    }
}
