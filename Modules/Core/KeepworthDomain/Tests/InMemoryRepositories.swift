import Foundation
import Testing

@testable import KeepworthDomain

/// The double of `LedgerChanges`. Repositories hold one and ring it on every write, the way
/// SQLite's observation fires because the file changed rather than because a particular
/// repository asked it to.
///
/// A lock and not an actor: registering a listener has to happen **before** `changes()`
/// returns. Deferring it to a `Task` would let a test write between subscribing and being
/// subscribed, and lose the notification it was waiting for — a flaky test that looks like a
/// bug in the code under test.
final class InMemoryLedgerChanges: LedgerChanges, @unchecked Sendable {
    private let lock = NSLock()
    private var listeners: [UUID: AsyncThrowingStream<Void, any Error>.Continuation] = [:]

    func changes() -> AsyncThrowingStream<Void, any Error> {
        // One slot, matching `SQLiteLedgerChanges`: two signals say the same thing as one.
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.withLock { listeners[id] = continuation }
            // Strong `self`, matching `SQLiteLedgerChanges`, where it is load-bearing: there
            // the stream has to keep the database observation alive. The retain ends when the
            // last listener does.
            continuation.onTermination = { [self] _ in
                lock.withLock { _ = listeners.removeValue(forKey: id) }
            }
        }
    }

    func notify() {
        // Copied out of the lock before use. `NSLock` is not reentrant, and a listener
        // released while the array is walked runs its `onTermination`, which takes this same
        // lock.
        let current = lock.withLock { Array(listeners.values) }
        for listener in current {
            listener.yield()
        }
    }
}

/// In-memory doubles of the repository protocols.
///
/// The domain knows no database, so its tests need none either. These doubles also prove
/// the protocols are sufficient: if a use case needed something missing here, the protocol
/// would be too narrow.
///
/// Actors because they now store writes, and the domain compiles under strict concurrency.
actor InMemoryInstitutionRepository: InstitutionRepository {
    private(set) var institutions: [Institution]
    private let changes: InMemoryLedgerChanges?

    init(_ institutions: [Institution] = [], changes: InMemoryLedgerChanges? = nil) {
        self.institutions = institutions
        self.changes = changes
    }

    func institution(withID id: InstitutionID) async throws -> Institution {
        guard let institution = institutions.first(where: { $0.id == id }) else {
            throw RepositoryError.institutionNotFound(id)
        }
        return institution
    }

    func allInstitutions() async throws -> [Institution] {
        institutions
    }

    func save(_ institution: Institution) async throws {
        if let index = institutions.firstIndex(where: { $0.id == institution.id }) {
            institutions[index] = institution
        } else {
            institutions.append(institution)
        }
        changes?.notify()
    }
}

actor InMemoryAccountRepository: AccountRepository {
    private(set) var accounts: [Account]
    private let changes: InMemoryLedgerChanges?

    init(_ accounts: [Account] = [], changes: InMemoryLedgerChanges? = nil) {
        self.accounts = accounts
        self.changes = changes
    }

    func account(withID id: AccountID) async throws -> Account {
        guard let account = accounts.first(where: { $0.id == id }) else {
            throw RepositoryError.accountNotFound(id)
        }
        return account
    }

    func accounts(ofKinds kinds: Set<AccountKind>) async throws -> [Account] {
        accounts.filter { kinds.contains($0.kind) }
    }

    func accounts(inInstitution id: InstitutionID) async throws -> [Account] {
        accounts.filter { $0.institutionID == id }
    }

    func save(_ account: Account) async throws {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        changes?.notify()
    }

    func archive(_ id: AccountID) async throws {
        let account = try await account(withID: id)
        try await save(
            Account(
                id: account.id,
                institutionID: account.institutionID,
                name: account.name,
                kind: account.kind,
                currency: account.currency,
                symbolName: account.symbolName,
                isSystem: account.isSystem,
                isArchived: true
            )
        )
    }
}

actor InMemoryEntryRepository: EntryRepository {
    private(set) var savedEntries: [Entry]
    /// Stands in for `created_at`, which the SQLite one uses to break ties between movements
    /// of the same day. Without it this double would order those the opposite way round from
    /// production, and a feature test would prove a first row the user never sees.
    private var savedOrder: [EntryID: Int] = [:]
    private var nextSavedOrder = 0
    private let changes: InMemoryLedgerChanges?

    init(_ entries: [Entry] = [], changes: InMemoryLedgerChanges? = nil) {
        self.changes = changes
        self.savedEntries = entries
        for entry in entries {
            savedOrder[entry.id] = nextSavedOrder
            nextSavedOrder += 1
        }
    }

    /// Upserts by id, like the SQLite one. Appending would make a re-saved entry count twice
    /// here and once in production, which is the kind of difference that makes a double prove
    /// something the real thing does not.
    func save(_ entry: Entry) async throws {
        if let existing = savedEntries.firstIndex(where: { $0.id == entry.id }) {
            savedEntries[existing] = entry
        } else {
            savedEntries.append(entry)
        }
        // Only on first save, mirroring `created_at`, which a re-save never rewrites.
        if savedOrder[entry.id] == nil {
            savedOrder[entry.id] = nextSavedOrder
            nextSavedOrder += 1
        }
        changes?.notify()
    }

    /// Unordered, unlike the SQLite one. Deliberate: every caller of this method sums what it
    /// gets — net worth, balances, the period report — so imitating an order nobody depends on
    /// would be inventing fidelity instead of having it.
    func lines(matching query: EntryLineQuery) async throws -> [EntryLine] {
        newestFirst(within: query.from, and: query.through)
            .flatMap(\.lines)
            .filter { query.accountIDs.contains($0.accountID) }
    }

    func entries(matching query: EntryQuery) async throws -> [Entry] {
        newestFirst(within: query.from, and: query.through)
            .filter { entry in
                guard let accountIDs = query.accountIDs else { return true }
                return entry.lines.contains { accountIDs.contains($0.accountID) }
            }
            .prefix(query.limit)
            .map { $0 }
    }

    /// Same order as `ORDER BY occurred_on DESC, created_at DESC` in the SQLite one.
    private func newestFirst(within from: CalendarDate?, and through: CalendarDate?) -> [Entry] {
        savedEntries
            .filter { entry in
                if let from, entry.occurredOn < from { return false }
                if let through, entry.occurredOn > through { return false }
                return true
            }
            .sorted { left, right in
                if left.occurredOn != right.occurredOn {
                    return left.occurredOn > right.occurredOn
                }
                return savedOrder[left.id, default: 0] > savedOrder[right.id, default: 0]
            }
    }
}

actor InMemorySettingsRepository: SettingsRepository {
    private var storedBaseCurrency: CurrencyCode?
    private let changes: InMemoryLedgerChanges?

    init(baseCurrency: CurrencyCode? = nil, changes: InMemoryLedgerChanges? = nil) {
        self.storedBaseCurrency = baseCurrency
        self.changes = changes
    }

    func baseCurrency() async throws -> CurrencyCode? {
        storedBaseCurrency
    }

    /// Rings the signal like the other three. In SQLite this is an `UPDATE` on `app_setting`,
    /// which falls inside the observed region — and it is the write with the widest reach in
    /// the app, because changing the base currency changes every figure on every screen.
    func setBaseCurrency(_ currency: CurrencyCode) async throws {
        storedBaseCurrency = currency
        changes?.notify()
    }
}
