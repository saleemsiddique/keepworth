import Testing

@testable import KeepworthDomain

/// Dobles en memoria de los protocolos de repositorio.
///
/// El dominio no conoce ninguna base de datos, así que sus tests tampoco necesitan una.
/// Estos dobles son también la demostración de que los protocolos son suficientes: si un
/// caso de uso necesitara algo que no está aquí, el protocolo se queda corto.
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

    /// Devuelve una copia con una cuenta más, para comprobar qué cambia y qué no al añadirla.
    func adding(_ account: Account) -> InMemoryAccountRepository {
        InMemoryAccountRepository(accounts + [account])
    }

    func replacing(_ account: Account) -> InMemoryAccountRepository {
        InMemoryAccountRepository(accounts.map { $0.id == account.id ? account : $0 })
    }
}

/// Es un actor porque guarda asientos: `save` muta, y el dominio se compila con concurrencia
/// estricta.
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
