import KeepworthDesignSystem
import KeepworthDomain
import SwiftUI

/// One movement as a row: who it was with, what it was filed under, and how much moved.
///
/// The colour follows the money account's leg, which `Entry.moneyLine` picks. Everything the
/// row needs is passed in already resolved — a view that looked accounts up while drawing
/// would query on every frame.
///
/// Lives in `FeatureSupport` because both Summary and Movements draw it, which is the second
/// use the project's rule waits for before extracting anything.
public struct MovementRow: View {
    private let entry: Entry
    private let accountNames: [AccountID: String]
    private let moneyAccountIDs: Set<AccountID>
    private let formatter: MoneyFormatter

    public init(
        entry: Entry,
        accountNames: [AccountID: String],
        moneyAccountIDs: Set<AccountID>,
        formatter: MoneyFormatter
    ) {
        self.entry = entry
        self.accountNames = accountNames
        self.moneyAccountIDs = moneyAccountIDs
        self.formatter = formatter
    }

    public var body: some View {
        LedgerRow(
            title: entry.payee ?? counterpartName ?? "",
            subtitle: subtitle,
            amount: amount,
            direction: direction
        )
    }

    private var moneyLine: EntryLine? {
        entry.moneyLine(among: moneyAccountIDs)
    }

    private var counterpartName: String? {
        guard let moneyLine, let other = entry.counterpartLine(of: moneyLine) else { return nil }
        return accountNames[other.accountID]
    }

    /// The account the money left or entered. With a payee on the title line, the subtitle is
    /// where the movement actually happened.
    private var subtitle: String? {
        guard let moneyLine, let name = accountNames[moneyLine.accountID] else { return nil }
        guard entry.payee != nil, let counterpart = counterpartName else { return name }
        return "\(name) · \(counterpart)"
    }

    private var amount: String {
        guard let moneyLine else { return "" }
        return formatter.signedString(for: moneyLine.amount)
    }

    private var direction: AmountDirection {
        guard let moneyLine else { return .neutral }
        return moneyLine.amount.isNegative ? .outgoing : .incoming
    }
}
