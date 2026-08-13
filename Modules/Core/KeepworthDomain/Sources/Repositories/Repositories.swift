/// Declared here, implemented in `KeepworthPersistence`. Features talk to these protocols,
/// never to GRDB, which is what makes them testable with in-memory doubles.
public protocol InstitutionRepository: Sendable {
    /// Throws instead of returning `nil`: a missing bank is a caller error, not a normal
    /// case every caller has to guard against.
    func institution(withID id: InstitutionID) async throws -> Institution
    func allInstitutions() async throws -> [Institution]
    /// Inserts it, or updates the stored one with the same id.
    func save(_ institution: Institution) async throws
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

public enum RepositoryError: Error, Equatable {
    case accountNotFound(AccountID)
    case institutionNotFound(InstitutionID)
}
