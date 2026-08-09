import Testing

@testable import KeepworthDomain

/// In-memory doubles of the repository protocols.
///
/// The domain knows no database, so its tests need none either. These doubles also prove
/// the protocols are sufficient: if a use case needed something missing here, the protocol
/// would be too narrow.
struct InMemoryInstitutionRepository: InstitutionRepository {
    let institutions: [Institution]

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
}

struct InMemoryAccountRepository: AccountRepository {
    let accounts: [Account]

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

    /// A copy with one more account, to check what changes and what does not.
    func adding(_ account: Account) -> InMemoryAccountRepository {
        InMemoryAccountRepository(accounts + [account])
    }

    func replacing(_ account: Account) -> InMemoryAccountRepository {
        InMemoryAccountRepository(accounts.map { $0.id == account.id ? account : $0 })
    }
}

/// An actor because it stores entries: `save` mutates, and the domain compiles under
/// strict concurrency.
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
