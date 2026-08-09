/// One leg of an entry: how much moved, and in which account.
///
/// Two amounts because they are two facts, not two views of one. `baseAmount` is **stored,
/// never derived**: multiplying `amount` by a rate leaves rounding dust that makes the
/// zero-sum invariant unreachable.
public struct EntryLine: Hashable, Sendable, Identifiable {
    public let id: EntryLineID
    public let accountID: AccountID
    /// What moved, in the account's currency. Negative out, positive in.
    public let amount: Money
    /// What it was worth in the user's currency, same sign.
    public let baseAmount: Money
    /// With three or more lines the origin stops being deducible, so it is stored.
    public let sortOrder: Int

    public init(
        id: EntryLineID = EntryLineID(),
        accountID: AccountID,
        amount: Money,
        baseAmount: Money,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.accountID = accountID
        self.amount = amount
        self.baseAmount = baseAmount
        self.sortOrder = sortOrder
    }

    /// Single-currency shorthand, where both amounts are the same.
    public init(
        id: EntryLineID = EntryLineID(),
        accountID: AccountID,
        amount: Money,
        sortOrder: Int = 0
    ) {
        self.init(
            id: id,
            accountID: accountID,
            amount: amount,
            baseAmount: amount,
            sortOrder: sortOrder
        )
    }
}
