import Foundation
import KeepworthDesignSystem
import KeepworthDomain
import Observation

/// What the movement editor holds while it is open, and what it writes when it closes.
///
/// The same screen records and corrects. Correcting sends the request it would send to
/// create, carrying the id of the movement on screen, so the entry is rewritten rather than
/// duplicated — including when its type changes, because the repository buries the legs the
/// previous version had.
@MainActor
@Observable
public final class MovementEditorModel {
    public enum State: Sendable {
        case loading
        case ready
        /// Nothing to edit with, and something to say about it.
        case failed
    }

    public private(set) var state: State = .loading

    public var type: MovementType = .expense {
        didSet {
            // The counterpart list changes with the type, so a category chosen for an expense
            // would otherwise stay selected under "transfer" and be saved as an account.
            if type != oldValue { counterpartID = nil }
        }
    }
    public var amount = DigitAmount()
    public var accountID: AccountID?
    public var counterpartID: AccountID?
    public var occurredOn: CalendarDate
    public var payee = ""
    public var note = ""

    public private(set) var moneyAccounts: [Account] = []
    public private(set) var lastFailure: MovementEditorFailure?

    private var expenseCategories: [Account] = []
    private var incomeCategories: [Account] = []
    private var baseCurrency: CurrencyCode?
    /// The movement being corrected. Nil for a new one.
    private let editing: Entry?
    private let accounts: any AccountRepository
    private let entries: any EntryRepository
    private let settings: any SettingsRepository

    public init(
        editing: Entry? = nil,
        accounts: any AccountRepository,
        entries: any EntryRepository,
        settings: any SettingsRepository,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.editing = editing
        self.accounts = accounts
        self.entries = entries
        self.settings = settings
        self.occurredOn = CalendarDate(now(), in: calendar)
    }

    /// Loads the accounts to choose from, and fills the fields in when correcting.
    ///
    /// No `observe`: this screen is open for as long as one movement takes to write, and a
    /// list of accounts that reshuffled underneath a half-made choice would be worse than one
    /// a few seconds old.
    public func load() async {
        do {
            guard let currency = try await settings.baseCurrency() else {
                state = .failed
                return
            }
            baseCurrency = currency

            // Archived accounts are gone from here and nowhere else: archiving takes an
            // account out of the editor, not out of the ledger.
            let live = try await accounts.accounts(ofKinds: [.asset, .liability, .expense, .income])
                .filter { !$0.isArchived && !$0.isSystem }

            moneyAccounts = live.filter { $0.kind.holdsMoney }
            expenseCategories = live.filter { $0.kind == .expense }
            incomeCategories = live.filter { $0.kind == .income }

            fillIn(from: live)
            state = .ready
        } catch {
            state = .failed
        }
    }

    /// Whether this is a correction rather than a new movement. Only the title says so:
    /// everything else about the two is the same, which is the point.
    public var isCorrecting: Bool { editing != nil }

    /// What the second picker offers, which is the whole reason the type switch exists.
    public var counterparts: [Account] {
        switch type {
        case .expense: expenseCategories
        case .income: incomeCategories
        // Its own destination would be an entry that does not move anything, and the domain
        // rejects it. Left out here so it is never offered in the first place.
        case .transfer: moneyAccounts.filter { $0.id != accountID }
        }
    }

    public func account(withID id: AccountID?) -> Account? {
        guard let id else { return nil }
        return (moneyAccounts + expenseCategories + incomeCategories).first { $0.id == id }
    }

    /// Money leaving is shown as leaving while it is being typed, so the figure on screen
    /// reads the way the row it becomes will.
    public var typedAmount: Money {
        let magnitude = Money(minorUnits: amount.minorUnits, currency: baseCurrency ?? .eur)
        guard type == .expense, !magnitude.isZero else { return magnitude }
        return (try? magnitude.negated()) ?? magnitude
    }

    public var availability: ActionAvailability {
        let isComplete =
            !amount.isZero && accountID != nil && counterpartID != nil
            && accountID != counterpartID
        return isComplete ? .available : .unavailable
    }

    /// Saves, and says whether the sheet should close.
    public func save() async -> Bool {
        guard
            let currency = baseCurrency,
            let accountID,
            let counterpartID
        else {
            lastFailure = .incomplete
            return false
        }
        let money = Money(minorUnits: amount.minorUnits, currency: currency)
        let trimmedPayee = payee.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            switch type {
            case .expense:
                try await RecordExpense(accounts: accounts, entries: entries).execute(
                    RecordExpense.Request(
                        id: editing?.id,
                        accountID: accountID,
                        categoryID: counterpartID,
                        amount: money,
                        occurredOn: occurredOn,
                        payee: trimmedPayee.isEmpty ? nil : trimmedPayee,
                        note: trimmedNote.isEmpty ? nil : trimmedNote
                    )
                )
            case .income:
                try await RecordIncome(accounts: accounts, entries: entries).execute(
                    RecordIncome.Request(
                        id: editing?.id,
                        accountID: accountID,
                        categoryID: counterpartID,
                        amount: money,
                        occurredOn: occurredOn,
                        payee: trimmedPayee.isEmpty ? nil : trimmedPayee,
                        note: trimmedNote.isEmpty ? nil : trimmedNote
                    )
                )
            case .transfer:
                try await TransferBetweenAccounts(accounts: accounts, entries: entries).execute(
                    TransferBetweenAccounts.Request(
                        id: editing?.id,
                        sourceAccountID: accountID,
                        destinationAccountID: counterpartID,
                        amount: money,
                        occurredOn: occurredOn,
                        note: trimmedNote.isEmpty ? nil : trimmedNote
                    )
                )
            }
            return true
        } catch MovementError.amountMustBePositive {
            lastFailure = .incomplete
            return false
        } catch {
            lastFailure = .writeFailed
            return false
        }
    }

    public func dismissFailure() {
        lastFailure = nil
    }

    /// Reads the stored movement back into the fields. A movement the editor cannot represent
    /// leaves them untouched, which is the case a starting balance falls into — and the reason
    /// the screens do not open it in the first place.
    private func fillIn(from live: [Account]) {
        guard let editing else { return }
        let kinds = Dictionary(
            live.map { ($0.id, $0.kind) },
            uniquingKeysWith: { first, _ in first }
        )
        guard let stored = EditableMovement(entry: editing, kinds: kinds) else { return }

        type = stored.type
        // After `type`, whose observer clears it.
        counterpartID = stored.counterpartID
        accountID = stored.accountID
        amount = DigitAmount(minorUnits: stored.minorUnits)
        occurredOn = stored.occurredOn
        payee = stored.payee ?? ""
        note = stored.note ?? ""
    }
}

public enum MovementEditorFailure: Hashable, Sendable {
    /// Something the screen should have prevented is still missing.
    case incomplete
    case writeFailed
}
