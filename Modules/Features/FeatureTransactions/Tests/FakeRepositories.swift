import Foundation
import KeepworthDomain

/// In-memory doubles of the `Domain` protocols.
///
/// A copy of the ones in `KeepworthDomain`'s test target and in `FeatureSummary`'s, which a
/// feature cannot reach: **a test target exports nothing**, so there is no way to share these
/// short of shipping test doubles in a production module. The copy is the lesser cost, and it
/// is the reason the fidelity notes below are repeated rather than referenced. Kept deliberately faithful to the SQLite implementations
/// in the two places where they used to differ and where a divergence would let a feature test
/// prove something production does not do — entries come back newest first with ties broken by
/// save order, and saving upserts by id instead of appending.
final class FakeLedgerChanges: LedgerChanges, @unchecked Sendable {
    private let lock = NSLock()
    private var listeners: [UUID: AsyncThrowingStream<Void, any Error>.Continuation] = [:]

    func changes() -> AsyncThrowingStream<Void, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.withLock { listeners[id] = continuation }
            continuation.onTermination = { [self] _ in
                lock.withLock { _ = listeners.removeValue(forKey: id) }
            }
        }
    }

    func notify() {
        let current = lock.withLock { Array(listeners.values) }
        for listener in current {
            listener.yield()
        }
    }
}

actor FakeInstitutionRepository: InstitutionRepository {
    private var stored: [Institution]
    private let changes: FakeLedgerChanges?

    init(_ institutions: [Institution] = [], changes: FakeLedgerChanges? = nil) {
        self.stored = institutions
        self.changes = changes
    }

    func institution(withID id: InstitutionID) async throws -> Institution {
        guard let institution = stored.first(where: { $0.id == id }) else {
            throw RepositoryError.institutionNotFound(id)
        }
        return institution
    }

    func allInstitutions() async throws -> [Institution] { stored }

    func save(_ institution: Institution) async throws {
        if let index = stored.firstIndex(where: { $0.id == institution.id }) {
            stored[index] = institution
        } else {
            stored.append(institution)
        }
        changes?.notify()
    }
}

actor FakeAccountRepository: AccountRepository {
    private var stored: [Account]
    private let changes: FakeLedgerChanges?

    init(_ accounts: [Account] = [], changes: FakeLedgerChanges? = nil) {
        self.stored = accounts
        self.changes = changes
    }

    func account(withID id: AccountID) async throws -> Account {
        guard let account = stored.first(where: { $0.id == id }) else {
            throw RepositoryError.accountNotFound(id)
        }
        return account
    }

    func accounts(ofKinds kinds: Set<AccountKind>) async throws -> [Account] {
        stored.filter { kinds.contains($0.kind) }
    }

    func accounts(inInstitution id: InstitutionID) async throws -> [Account] {
        stored.filter { $0.institutionID == id }
    }

    func save(_ account: Account) async throws {
        if let index = stored.firstIndex(where: { $0.id == account.id }) {
            stored[index] = account
        } else {
            stored.append(account)
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

actor FakeEntryRepository: EntryRepository {
    private var stored: [Entry] = []
    /// Stands in for `created_at`, which the SQLite one uses to break ties between movements
    /// of the same day.
    private var savedOrder: [EntryID: Int] = [:]
    private var nextSavedOrder = 0
    private let changes: FakeLedgerChanges?

    init(changes: FakeLedgerChanges? = nil) {
        self.changes = changes
    }

    func save(_ entry: Entry) async throws {
        if let index = stored.firstIndex(where: { $0.id == entry.id }) {
            stored[index] = entry
        } else {
            stored.append(entry)
        }
        if savedOrder[entry.id] == nil {
            savedOrder[entry.id] = nextSavedOrder
            nextSavedOrder += 1
        }
        changes?.notify()
    }

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

    private func newestFirst(within from: CalendarDate?, and through: CalendarDate?) -> [Entry] {
        stored
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

actor FakeSettingsRepository: SettingsRepository {
    private var stored: CurrencyCode?
    private let changes: FakeLedgerChanges?

    init(baseCurrency: CurrencyCode? = nil, changes: FakeLedgerChanges? = nil) {
        self.stored = baseCurrency
        self.changes = changes
    }

    func baseCurrency() async throws -> CurrencyCode? { stored }

    func setBaseCurrency(_ currency: CurrencyCode) async throws {
        stored = currency
        changes?.notify()
    }

    /// Only a test does this: it stands for a ledger that was never seeded.
    func forget() {
        stored = nil
    }
}
