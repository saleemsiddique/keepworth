/// Declared here, implemented in `KeepworthPersistence`. Features talk to these protocols,
/// never to GRDB, which is what makes them testable with in-memory doubles.
public protocol InstitutionRepository: Sendable {
    /// Throws instead of returning `nil`: a missing bank is a caller error, not a normal
    /// case every caller has to guard against.
    func institution(withID id: InstitutionID) async throws -> Institution
    func allInstitutions() async throws -> [Institution]
    /// Inserts it, or updates the stored one with the same id.
    func save(_ institution: Institution) async throws
    /// A bank the user no longer deals with: it leaves the pickers and keeps its accounts.
    ///
    /// There is no delete. A bank with live accounts must not disappear, and one without
    /// them is cheap to leave archived, so archiving is the whole of it.
    func archive(_ id: InstitutionID) async throws
    func unarchive(_ id: InstitutionID) async throws
}

public protocol AccountRepository: Sendable {
    func account(withID id: AccountID) async throws -> Account
    func accounts(ofKinds kinds: Set<AccountKind>) async throws -> [Account]
    func accounts(inInstitution id: InstitutionID) async throws -> [Account]
    /// Inserts it, or updates the stored one with the same id.
    func save(_ account: Account) async throws
    /// Archiving is what happens instead of deleting once an account has movements:
    /// it leaves the editor but keeps its history.
    func archive(_ id: AccountID) async throws
    /// Puts it back in the editor. Archiving has to be undoable or it reads as deleting,
    /// and the user would stop trusting it with an account they still use.
    func unarchive(_ id: AccountID) async throws
}

/// Preferences that follow the user across devices. Small and few, so one typed accessor
/// per setting rather than a generic key-value bag.
public protocol SettingsRepository: Sendable {
    /// The currency every account shares. `nil` until the user picks one on first launch.
    func baseCurrency() async throws -> CurrencyCode?
    func setBaseCurrency(_ currency: CurrencyCode) async throws
}

public protocol EntryRepository: Sendable {
    func save(_ entry: Entry) async throws
    /// Returns **live** lines only: neither the line nor its entry may be deleted. Filtering
    /// on the line alone leaves lines of deleted entries alive and silently unbalances
    /// balances.
    func lines(matching query: EntryLineQuery) async throws -> [EntryLine]
    /// Whole movements, newest first, for the screens that show what happened rather than
    /// what it adds up to.
    ///
    /// Every entry comes back with **all** its lines. There is no partial `Entry`: one would
    /// not balance, and `Entry.init` would reject it.
    func entries(matching query: EntryQuery) async throws -> [Entry]
    /// Buries a movement: the entry and every one of its lines get a tombstone.
    ///
    /// Not a `DELETE`. A row that vanishes leaves nothing for the next sync to notice, so it
    /// comes back from another device as if it had never been removed.
    ///
    /// **Both the entry and its lines**, not just the entry. Reads already ignore a line whose
    /// entry is buried, so entry-only would look right on screen — but a line with no tombstone
    /// of its own is a line the sync has no reason to remove anywhere else.
    func delete(_ id: EntryID) async throws
    /// Brings back a movement that was just buried, which is what the undo after a swipe does.
    ///
    /// Takes the whole `Entry` and not its id: the caller is holding the one it removed, and
    /// that says exactly which lines to revive. Deriving them from the tombstone instant
    /// looked tidier and was wrong — an entry edited and then deleted can carry two burials
    /// stamped at the same moment, and undo brought back a four-legged movement that could
    /// not balance.
    func restore(_ entry: Entry) async throws
}

/// One query type instead of a method per combination: net worth asks for some accounts up
/// to a date and the report asks for a range, but it is the same question.
public struct EntryLineQuery: Hashable, Sendable {
    /// Always explicit. There is no "all accounts": no domain question needs it, and an
    /// unfiltered query over a long history is the one nobody should write by accident.
    public let accountIDs: Set<AccountID>
    /// `nil` means from the beginning.
    public let from: CalendarDate?
    /// `nil` means to the end, **including the future**.
    public let through: CalendarDate?

    public init(
        accountIDs: Set<AccountID>,
        from: CalendarDate? = nil,
        through: CalendarDate? = nil
    ) {
        self.accountIDs = accountIDs
        self.from = from
        self.through = through
    }
}

/// Which movements to show, for the screens that list them.
///
/// Separate from `EntryLineQuery` because it asks a different question. That one asks what a
/// set of accounts adds up to and answers with legs; this one asks what happened and answers
/// with whole movements.
public struct EntryQuery: Hashable, Sendable {
    /// Movements touching **any** of these accounts. `nil` means any account.
    ///
    /// Filtering picks **which entries**, never which lines: an expense has one leg on the
    /// card and another on the category, and returning only the matching leg would hand back
    /// an entry that does not sum to zero.
    public let accountIDs: Set<AccountID>?
    /// `nil` means from the beginning.
    public let from: CalendarDate?
    /// `nil` means to the end, **including the future**.
    public let through: CalendarDate?
    /// How many, newest first. Mandatory, and that is the point: a screen that scrolls a long
    /// history is exactly where an unbounded query gets written by accident.
    public let limit: Int

    public init(
        accountIDs: Set<AccountID>? = nil,
        from: CalendarDate? = nil,
        through: CalendarDate? = nil,
        limit: Int
    ) throws {
        guard limit > 0 else {
            throw EntryQueryError.limitMustBePositive(limit)
        }
        self.accountIDs = accountIDs
        self.from = from
        self.through = through
        self.limit = limit
    }
}

public enum EntryQueryError: Error, Equatable {
    /// Asking for zero or fewer movements is a caller mistake. It also matters downstream:
    /// SQLite reads a negative `LIMIT` as no limit at all, so letting one through would turn
    /// the guard into its opposite.
    case limitMustBePositive(Int)
}

public enum RepositoryError: Error, Equatable {
    case accountNotFound(AccountID)
    case institutionNotFound(InstitutionID)
    case entryNotFound(EntryID)
}
