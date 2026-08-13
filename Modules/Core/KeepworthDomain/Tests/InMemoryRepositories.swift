import Testing

@testable import KeepworthDomain

/// In-memory doubles of the repository protocols.
///
/// The domain knows no database, so its tests need none either. These doubles also prove
/// the protocols are sufficient: if a use case needed something missing here, the protocol
/// would be too narrow.
///
/// Actors because they now store writes, and the domain compiles under strict concurrency.
actor InMemoryInstitutionRepository: InstitutionRepository {
    private(set) var institutions: [Institution]

    init(_ institutions: [Institution] = []) {
        self.institutions = institutions
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
    }
}

actor InMemoryAccountRepository: AccountRepository {
    private(set) var accounts: [Account]

    init(_ accounts: [Account] = []) {
        self.accounts = accounts
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

    init(_ entries: [Entry] = []) {
        self.savedEntries = entries
    }

    func save(_ entry: Entry) async throws {
        savedEntries.append(entry)
    }

    func lines(matching query: EntryLineQuery) async throws -> [EntryLine] {
        savedEntries
            .filter { entry in
                if let from = query.from, entry.occurredOn < from { return false }
                if let through = query.through, entry.occurredOn > through { return false }
                return true
            }
            .flatMap(\.lines)
            .filter { query.accountIDs.contains($0.accountID) }
    }
}

actor InMemorySettingsRepository: SettingsRepository {
    private var storedBaseCurrency: CurrencyCode?

    init(baseCurrency: CurrencyCode? = nil) {
        self.storedBaseCurrency = baseCurrency
    }

    func baseCurrency() async throws -> CurrencyCode? {
        storedBaseCurrency
    }

    func setBaseCurrency(_ currency: CurrencyCode) async throws {
        storedBaseCurrency = currency
    }
}
