import KeepworthDesignSystem
import KeepworthDomain
import SwiftUI

/// What a movement reads as, worked out once and away from any view.
///
/// A separate type because the interesting part is the mapping, and a `View` cannot be
/// asserted on: the colour a movement takes is the design system's loudest rule, and a test
/// that only builds the row would pass with it inverted.
public struct MovementReading: Hashable, Sendable {
    public let title: String
    public let subtitle: String?
    public let amount: String
    public let direction: AmountDirection

    public init(
        entry: Entry,
        accountNames: [AccountID: String],
        moneyAccountIDs: Set<AccountID>,
        formatter: MoneyFormatter
    ) {
        let moneyLine = entry.moneyLine(among: moneyAccountIDs)
        let counterpart = moneyLine.flatMap { entry.counterpartLine(of: $0) }
        let accountName = moneyLine.flatMap { accountNames[$0.accountID] }
        let counterpartName = counterpart.flatMap { accountNames[$0.accountID] }

        // The payee if there is one, else what it was filed under, else the account. Never
        // empty: a row with only a figure and no words is unreadable, and the account is
        // always known.
        self.title = entry.payee ?? counterpartName ?? accountName ?? ""

        // With a payee on the title line, the subtitle says where it happened and under what.
        // Without one, the title already carries the category and repeating it adds nothing.
        if entry.payee != nil, let accountName {
            self.subtitle = counterpartName.map { "\(accountName) · \($0)" } ?? accountName
        } else {
            self.subtitle = entry.payee == nil ? nil : accountName
        }

        self.amount = moneyLine.map { formatter.signedString(for: $0.amount) } ?? ""
        switch moneyLine?.amount {
        case .some(let amount) where amount.isNegative: self.direction = .outgoing
        case .some(let amount) where amount.isPositive: self.direction = .incoming
        default: self.direction = .neutral
        }
    }
}

/// One movement as a row: who it was with, what it was filed under, and how much moved.
///
/// Lives in `FeatureSupport` because both Summary and Movements draw it, which is the second
/// use the project's rule waits for before extracting anything. Everything it needs arrives
/// already resolved — a view that looked accounts up while drawing would query on every frame.
public struct MovementRow: View {
    private let reading: MovementReading

    public init(
        entry: Entry,
        accountNames: [AccountID: String],
        moneyAccountIDs: Set<AccountID>,
        formatter: MoneyFormatter
    ) {
        self.reading = MovementReading(
            entry: entry,
            accountNames: accountNames,
            moneyAccountIDs: moneyAccountIDs,
            formatter: formatter
        )
    }

    public var body: some View {
        LedgerRow(
            title: reading.title,
            subtitle: reading.subtitle,
            amount: reading.amount,
            direction: reading.direction
        )
    }
}
