/// The three things the user records, as they think of them.
///
/// Not a domain type. In the ledger all three are the same two-line entry and only the kinds
/// of the accounts on each side differ, which is why `Domain` has no such enum. It exists
/// here because the screen has to ask, and because what the second picker offers depends on
/// the answer.
public enum MovementType: Hashable, Sendable, CaseIterable {
    /// Money leaves an account and is charged to an expense category.
    case expense
    /// Money leaves an income category and enters an account.
    case income
    /// Money moves between two accounts of the user's own. Net worth does not change.
    case transfer
}
