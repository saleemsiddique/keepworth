/// What came in, what went out and what was saved between two dates, by category.
///
/// Takes any range. Opening on the current month is a UI decision, not a domain one.
///
/// Transfers stay out without being excluded: both their legs are money accounts and this
/// only looks at categories. Opening balances stay out too, since their counterpart is
/// `equity`.
public struct SummarizePeriod: Sendable {
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.entries = entries
    }

    public func execute(
        from: CalendarDate,
        through: CalendarDate,
        in baseCurrency: CurrencyCode
    ) async throws -> PeriodSummary {
        let categories = try await accounts.accounts(ofKinds: [.expense, .income])
        // `uniquingKeysWith` rather than `uniqueKeysWithValues`, which traps on duplicate
        // ids: corrupt data must not kill the app while the user reads their report.
        let kindsByAccount = Dictionary(
            categories.map { ($0.id, $0.kind) },
            uniquingKeysWith: { first, _ in first }
        )

        let lines = try await entries.lines(
            matching: EntryLineQuery(
                accountIDs: Set(categories.map(\.id)),
                from: from,
                through: through
            )
        )

        // Expense lines are positive and income lines negative, because income categories
        // are where the money comes from. The report shows both as magnitudes.
        let expenseLines = lines.filter { kindsByAccount[$0.accountID] == .expense }
        let incomeLines = lines.filter { kindsByAccount[$0.accountID] == .income }

        let declaredOpeningBalances = try await openingBalances(
            from: from,
            through: through,
            in: baseCurrency
        )

        return try PeriodSummary(
            from: from,
            through: through,
            income: try totalsByAccount(incomeLines, in: baseCurrency, negated: true),
            expenses: try totalsByAccount(expenseLines, in: baseCurrency, negated: false),
            openingBalances: declaredOpeningBalances,
            baseCurrency: baseCurrency
        )
    }

    /// Money that entered the user's accounts by declaring a starting balance.
    ///
    /// Not income — you did not earn it — but it does raise net worth. Without this figure
    /// the report and net worth would disagree in any period where an account is created.
    private func openingBalances(
        from: CalendarDate,
        through: CalendarDate,
        in baseCurrency: CurrencyCode
    ) async throws -> Money {
        let openingBalanceAccounts = try await accounts.accounts(ofKinds: [.equity])
        guard !openingBalanceAccounts.isEmpty else {
            return .zero(in: baseCurrency)
        }

        let lines = try await entries.lines(
            matching: EntryLineQuery(
                accountIDs: Set(openingBalanceAccounts.map(\.id)),
                from: from,
                through: through
            )
        )
        // These lines are the counterpart, so what was contributed is their sum negated.
        return try Money.sum(lines.map(\.baseAmount), in: baseCurrency).negated()
    }

    private func totalsByAccount(
        _ lines: [EntryLine],
        in baseCurrency: CurrencyCode,
        negated: Bool
    ) throws -> [AccountTotal] {
        let linesByAccount = Dictionary(grouping: lines, by: \.accountID)

        let totals = try linesByAccount.map { accountID, lines in
            let total = try Money.sum(lines.map(\.baseAmount), in: baseCurrency)
            return AccountTotal(accountID: accountID, total: negated ? try total.negated() : total)
        }
        // Largest first: a report is read to find where the money went.
        return totals.sorted { $0.total.minorUnits > $1.total.minorUnits }
    }
}

/// How much went through a category in the period, as a positive magnitude.
public struct AccountTotal: Hashable, Sendable {
    public let accountID: AccountID
    public let total: Money

    public init(accountID: AccountID, total: Money) {
        self.accountID = accountID
        self.total = total
    }
}

/// A period's report.
///
/// `netWorthChange` is exactly what net worth moved between `from` and `through`, and a
/// test proves it against `CalculateNetWorth`.
///
/// `saved` alone is not enough for that equality: declaring a new account's starting
/// balance raises net worth without being income, so it is kept apart in `openingBalances`
/// rather than inflating what the user thinks they earned this month.
public struct PeriodSummary: Hashable, Sendable {
    public let from: CalendarDate
    public let through: CalendarDate
    public let income: [AccountTotal]
    public let expenses: [AccountTotal]
    public let baseCurrency: CurrencyCode
    public let totalIncome: Money
    public let totalExpenses: Money
    /// Income minus expenses. Negative if more went out than came in.
    public let saved: Money
    /// Starting balances declared in the period. Zero in a normal one.
    public let openingBalances: Money
    /// What net worth moved in the period: `saved` plus `openingBalances`.
    public let netWorthChange: Money

    /// Totals are computed once here instead of being throwing properties: a SwiftUI view
    /// cannot `try` in its body, and a `try?` per figure would turn a data error into a
    /// blank space.
    public init(
        from: CalendarDate,
        through: CalendarDate,
        income: [AccountTotal],
        expenses: [AccountTotal],
        openingBalances: Money,
        baseCurrency: CurrencyCode
    ) throws {
        self.from = from
        self.through = through
        self.income = income
        self.expenses = expenses
        self.baseCurrency = baseCurrency
        self.openingBalances = openingBalances
        self.totalIncome = try Money.sum(income.map(\.total), in: baseCurrency)
        self.totalExpenses = try Money.sum(expenses.map(\.total), in: baseCurrency)
        self.saved = try totalIncome - totalExpenses
        self.netWorthChange = try saved + openingBalances
    }
}
