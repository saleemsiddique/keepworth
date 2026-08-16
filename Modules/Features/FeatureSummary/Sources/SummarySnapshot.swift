import KeepworthDomain

/// Everything the summary screen draws, in the order it draws it.
///
/// Assembled once per load so the view has nothing to compute. A SwiftUI body cannot `try`,
/// and a screen that sorts and totals while it draws recomputes on every frame.
public struct SummarySnapshot: Sendable {
    public let netWorth: Money
    /// What net worth moved this month. Taken from `PeriodSummary.netWorthChange` rather than
    /// from two net worth readings, so the headline figure and the report cannot disagree —
    /// which is the whole reason the ledger is double entry.
    public let monthChange: Money
    /// Banks with their accounts, newest total first.
    public let institutions: [InstitutionBalance]
    /// Accounts belonging to no bank — cash, mostly. They go loose at the end.
    public let unbanked: [AccountBalance]
    public let month: PeriodSummary
    public let recent: [Entry]
    /// Every account by id, **categories included**. A movement's row names the category it
    /// was filed under and the report names them all, so a map of money accounts alone leaves
    /// both blank.
    public let accountNames: [AccountID: String]
    /// The accounts that hold money, which is what decides which leg of a movement is "the
    /// amount". See `Entry.moneyLine`.
    public let moneyAccountIDs: Set<AccountID>
    public let baseCurrency: CurrencyCode
}

public struct InstitutionBalance: Sendable, Identifiable {
    public let institution: Institution
    public let total: Money
    public let accounts: [AccountBalance]

    public var id: InstitutionID { institution.id }
}

public struct AccountBalance: Sendable, Identifiable {
    public let account: Account
    public let balance: Money

    public var id: AccountID { account.id }
}
