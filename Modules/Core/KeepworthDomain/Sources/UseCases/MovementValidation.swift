/// Checked before building the entry so the error names what is wrong — an archived
/// account, a negative amount — instead of a generic "does not balance".
func validateMovement(of amount: Money, outOf source: Account, into destination: Account) throws {
    guard amount.isPositive else {
        throw MovementError.amountMustBePositive
    }
    guard source.id != destination.id else {
        throw MovementError.sameAccountOnBothSides(source.id)
    }
    try validateAcceptsNewMovements(source)
    try validateAcceptsNewMovements(destination)
    guard source.currency == destination.currency else {
        throw MovementError.currencyMismatch(expected: source.currency, found: destination.currency)
    }
    guard amount.currency == source.currency else {
        throw MovementError.currencyMismatch(expected: source.currency, found: amount.currency)
    }
}

private func validateAcceptsNewMovements(_ account: Account) throws {
    guard !account.isArchived else {
        throw MovementError.archivedAccount(account.id)
    }
}

func validateHoldsMoney(_ account: Account) throws {
    guard account.kind.holdsMoney else {
        throw MovementError.accountCannotHoldMoney(account.kind)
    }
}

func validateIsCategory(_ account: Account, ofKind expected: AccountKind) throws {
    guard account.kind == expected else {
        throw MovementError.wrongCategoryKind(expected: expected, found: account.kind)
    }
}

public enum MovementError: Error, Equatable {
    /// The user always enters how much moved, positive. The sign comes from which side each
    /// account sits on.
    case amountMustBePositive
    /// A category was used where an account holding money was needed.
    case accountCannotHoldMoney(AccountKind)
    case wrongCategoryKind(expected: AccountKind, found: AccountKind)
    case sameAccountOnBothSides(AccountID)
    case currencyMismatch(expected: CurrencyCode, found: CurrencyCode)
    /// An archived account keeps its history but takes no new movements.
    case archivedAccount(AccountID)
    case openingBalanceMustNotBeZero
    /// The internal "Opening balance" account is missing. The first-launch seed creates it,
    /// and without it there is nothing to balance a starting balance against.
    case missingOpeningBalanceAccount
}
