import Foundation
import KeepworthDesignSystem
import KeepworthDomain
import Observation

/// The form behind adding a place to hold money, and behind correcting one.
///
/// Both at once because they are the same fields with one difference: the starting balance is
/// asked for only when the account is new. Correcting it afterwards would mean editing an
/// entry that already exists, which is the movement editor's job and not this screen's.
@MainActor
@Observable
public final class AccountForm {
    public var name = ""
    public var kind: AccountKind = .asset
    public var bankID: InstitutionID?
    public var symbolName: String?
    /// What the account already held, as a magnitude. Its sign comes from `kind`.
    public var startingBalance = DigitAmount()

    public private(set) var lastFailure: AccountFormFailure?

    /// The account being corrected, or `nil` when opening a new one.
    private let editing: Account?
    private let currency: CurrencyCode
    private let accounts: any AccountRepository
    private let entries: any EntryRepository
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(
        editing: Account? = nil,
        currency: CurrencyCode,
        accounts: any AccountRepository,
        entries: any EntryRepository,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.editing = editing
        self.currency = currency
        self.accounts = accounts
        self.entries = entries
        self.calendar = calendar
        self.now = now

        if let editing {
            self.name = editing.name
            self.kind = editing.kind
            self.bankID = editing.institutionID
            self.symbolName = editing.symbolName
        }
    }

    /// A starting balance belongs to an account that does not exist yet. On one that does, the
    /// figure is already in the ledger as an entry.
    public var asksForStartingBalance: Bool { editing == nil }

    /// Neither changes on an account that exists: an asset that became a liability would make
    /// every figure already derived from it a lie, and there is no currency to change to until
    /// multi-currency lands.
    public var canChooseKind: Bool { editing == nil }

    public var availability: ActionAvailability {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .unavailable : .available
    }

    /// Saves, and says whether the screen should close. `false` leaves it open with the
    /// failure showing, which is the only way the user can act on it.
    public func save() async -> Bool {
        do {
            if let editing {
                try await UpdateAccount(accounts: accounts).execute(
                    UpdateAccount.Request(
                        accountID: editing.id,
                        name: name,
                        institutionID: bankID,
                        symbolName: symbolName
                    )
                )
            } else {
                try await CreateAccount(accounts: accounts, entries: entries).execute(
                    CreateAccount.Request(
                        name: name,
                        kind: kind,
                        institutionID: bankID,
                        currency: currency,
                        symbolName: symbolName,
                        startingBalance: startingMoney,
                        asOf: CalendarDate(now(), in: calendar)
                    )
                )
            }
            return true
        } catch AccountError.blankName {
            lastFailure = .blankName
            return false
        } catch AccountError.systemAccountCannotChange {
            lastFailure = .systemAccount
            return false
        } catch {
            lastFailure = .writeFailed
            return false
        }
    }

    public func dismissFailure() {
        lastFailure = nil
    }

    /// What has been typed so far, signed. Public because the screen shows it, and computed
    /// here rather than there so the rule that gives it its sign is testable.
    ///
    /// The sign comes from the kind and not from a switch the user has to find: what a card
    /// already held is money owed, and what an account already held is money there.
    public var typedStartingBalance: Money {
        let magnitude = Money(minorUnits: startingBalance.minorUnits, currency: currency)
        guard kind == .liability, !magnitude.isZero else { return magnitude }
        return (try? magnitude.negated()) ?? magnitude
    }

    /// Zero is the absence of a starting balance, not a starting balance of nothing, so it
    /// records no entry at all.
    private var startingMoney: Money? {
        startingBalance.isZero ? nil : typedStartingBalance
    }
}

public enum AccountFormFailure: Hashable, Sendable {
    case blankName
    case systemAccount
    case writeFailed
}
