/// A movement in double entry: money leaves one place and enters another.
///
/// €42.30 spent is not a loose "−42.30": it is two lines, one lowering the account and one
/// charging a category. That is why the period report and the net worth delta cannot
/// contradict each other.
///
/// This initialiser is the only way to make a movement, and it rejects anything that does
/// not balance. An invalid entry never comes into existence.
public struct Entry: Hashable, Sendable, Identifiable {
    public let id: EntryID
    /// A future-dated entry does not count towards net worth until its day arrives.
    public let occurredOn: CalendarDate
    public let payee: String?
    public let note: String?
    public let lines: [EntryLine]

    public init(
        id: EntryID = EntryID(),
        occurredOn: CalendarDate,
        payee: String? = nil,
        note: String? = nil,
        lines: [EntryLine]
    ) throws {
        guard lines.count >= 2 else {
            throw EntryError.needsAtLeastTwoLines(found: lines.count)
        }

        let baseCurrency = lines[0].baseAmount.currency
        guard lines.allSatisfy({ $0.baseAmount.currency == baseCurrency }) else {
            throw EntryError.mixedBaseCurrencies
        }

        let residual = try Money.sum(lines.map(\.baseAmount), in: baseCurrency)
        guard residual.isZero else {
            throw EntryError.unbalanced(residual: residual)
        }

        self.id = id
        self.occurredOn = occurredOn
        self.payee = payee?.trimmedForStorageOrNil
        self.note = note?.trimmedForStorageOrNil
        self.lines = lines
    }

    public var baseCurrency: CurrencyCode { lines[0].baseAmount.currency }
}

public enum EntryError: Error, Equatable {
    /// A one-line movement is a loose number, not accounting: it says neither where the
    /// money came from nor where it went.
    case needsAtLeastTwoLines(found: Int)
    /// What went out and what came in do not match. `residual` is the difference.
    case unbalanced(residual: Money)
    /// Lines disagree on the base currency. There is only one, so some amount is wrong.
    case mixedBaseCurrencies
}
