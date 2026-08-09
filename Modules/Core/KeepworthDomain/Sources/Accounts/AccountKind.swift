/// What an account is, and therefore how it behaves.
///
/// There is no `Category` type: a category is an `.expense` or `.income` account, which is
/// what makes expense, income and transfer the same operation.
public enum AccountKind: String, CaseIterable, Hashable, Sendable {
    /// Bank accounts, cash, wallets.
    case asset
    /// Credit cards, loans.
    case liability
    /// Expense category.
    case expense
    /// Income category.
    case income
    /// Counterpart of opening balances. Internal and hidden.
    case equity

    /// A category returning `true` here would tell the user they have money they do not
    /// have: the worst bug this app can ship.
    public var countsTowardsNetWorth: Bool {
        switch self {
        case .asset, .liability: true
        case .expense, .income, .equity: false
        }
    }

    /// Whether it is a place holding real money. A category's "balance" is not a balance,
    /// it is how much went through it.
    public var holdsMoney: Bool {
        switch self {
        case .asset, .liability: true
        case .expense, .income, .equity: false
        }
    }

    /// Derived rather than repeating the list: a bank groups places holding money, so the
    /// day these diverge it is the definition of a bank that changed.
    public var canBelongToInstitution: Bool { holdsMoney }
}
