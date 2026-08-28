import KeepworthDomain

/// A stored movement read back into the fields the editor shows.
///
/// The ledger keeps two balanced legs and no notion of "expense" or "transfer"; the editor
/// asks in those terms. This is the translation back, and it lives in a type of its own
/// rather than inside the model because it is a rule about accounting — which leg is the
/// account and which the counterpart — and a rule that can be asserted on.
///
/// Failing to build is a real answer, not an error: a starting balance is booked against the
/// internal equity account, which appears in no picker. The editor cannot represent it, and
/// saving it as anything else would turn it into a movement the user never made.
public struct EditableMovement: Hashable, Sendable {
    public let id: EntryID
    public let type: MovementType
    /// The account the money moved out of, or into for income.
    public let accountID: AccountID
    /// The category it was filed under, or the account it went to.
    public let counterpartID: AccountID
    /// Always positive. The direction lives in `type`, not in the sign.
    public let minorUnits: Int64
    public let occurredOn: CalendarDate
    public let payee: String?
    public let note: String?

    /// `kinds` says what each account is. The editor has them loaded already, and passing them
    /// in keeps this a pure function of what it is given.
    public init?(entry: Entry, kinds: [AccountID: AccountKind]) {
        guard entry.lines.count == 2 else { return nil }

        let moneyAccountIDs = Set(
            kinds.filter { $0.value.holdsMoney }.map(\.key)
        )
        guard
            let money = entry.moneyLine(among: moneyAccountIDs),
            let other = entry.counterpartLine(of: money),
            let otherKind = kinds[other.accountID]
        else { return nil }

        switch otherKind {
        case .expense:
            self.type = .expense
        case .income:
            self.type = .income
        case .asset, .liability:
            self.type = .transfer
        case .equity:
            // A starting balance. It has no place in any picker, so there is nothing here to
            // put on screen.
            return nil
        }

        // `moneyLine` hands back the leg the money left, so its amount is negative for an
        // expense and for the source of a transfer. Income is the one case where it is
        // positive, and the magnitude is what the editor shows either way.
        self.id = entry.id
        self.accountID = money.accountID
        self.counterpartID = other.accountID
        self.minorUnits = abs(money.amount.minorUnits)
        self.occurredOn = entry.occurredOn
        self.payee = entry.payee
        self.note = entry.note
    }
}
