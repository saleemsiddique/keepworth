import Foundation
import GRDB
import KeepworthDomain
import Testing

@testable import KeepworthPersistence

@Test("An account survives a round trip through SQLite unchanged")
func roundTripsAnAccount() async throws {
    let ledger = try LedgerOnDisk()
    let bbva = try Institution(name: "BBVA")
    try await ledger.institutions.save(bbva)
    let original = try Account(
        institutionID: bbva.id,
        name: "Nómina",
        kind: .asset,
        currency: .eur,
        symbolName: "banknote"
    )

    try await ledger.accounts.save(original)

    #expect(try await ledger.accounts.account(withID: original.id) == original)
}

@Test("Saving an account twice updates it instead of duplicating it")
func savingTwiceUpdates() async throws {
    let ledger = try LedgerOnDisk()
    let original = try Account(name: "Efectivo", kind: .asset, currency: .eur)
    try await ledger.accounts.save(original)

    let renamed = try Account(id: original.id, name: "Cash", kind: .asset, currency: .eur)
    try await ledger.accounts.save(renamed)

    #expect(try await ledger.accounts.accounts(ofKinds: [.asset]).map(\.name) == ["Cash"])
}

@Test("Updating an account keeps the date it was created")
func updatePreservesCreationDate() async throws {
    let ledger = try LedgerOnDisk()
    let original = try Account(name: "Efectivo", kind: .asset, currency: .eur)
    try await ledger.accounts.save(original)

    let later = LedgerOnDisk.creationDate.addingTimeInterval(86400)
    let laterRepository = SQLiteAccountRepository(database: ledger.database, now: { later })
    try await laterRepository.save(
        Account(id: original.id, name: "Cash", kind: .asset, currency: .eur)
    )

    let identifier = original.id.rawValue.uuidString
    let createdAt = try await ledger.database.writer.read { database in
        try Date.fetchOne(
            database,
            sql: "SELECT created_at FROM account WHERE id = ?",
            arguments: [identifier]
        )
    }
    let updatedAt = try await ledger.database.writer.read { database in
        try Date.fetchOne(
            database,
            sql: "SELECT updated_at FROM account WHERE id = ?",
            arguments: [identifier]
        )
    }
    #expect(createdAt == LedgerOnDisk.creationDate)
    #expect(updatedAt == later)
}

@Test("A missing account throws instead of returning nothing")
func missingAccountThrows() async throws {
    let ledger = try LedgerOnDisk()
    let unknown = AccountID()

    await #expect(throws: RepositoryError.accountNotFound(unknown)) {
        try await ledger.accounts.account(withID: unknown)
    }
}

@Test("Archiving marks the account without removing it")
func archivingKeepsTheRow() async throws {
    let ledger = try LedgerOnDisk()
    let account = try Account(name: "Efectivo", kind: .asset, currency: .eur)
    try await ledger.accounts.save(account)

    try await ledger.accounts.archive(account.id)

    #expect(try await ledger.accounts.account(withID: account.id).isArchived)
}

@Test("A soft-deleted account disappears from every query but stays in the table")
func softDeletedAccountDisappears() async throws {
    let ledger = try LedgerOnDisk()
    let account = try Account(name: "Efectivo", kind: .asset, currency: .eur)
    try await ledger.accounts.save(account)

    try await ledger.database.writer.write { database in
        try database.execute(
            sql: "UPDATE account SET deleted_at = ? WHERE id = ?",
            arguments: [Date(), account.id.rawValue.uuidString]
        )
    }

    #expect(try await ledger.accounts.accounts(ofKinds: [.asset]).isEmpty)
    await #expect(throws: RepositoryError.accountNotFound(account.id)) {
        try await ledger.accounts.account(withID: account.id)
    }
    // Still on the table: without a tombstone the row would come back on the next sync.
    let rows = try await ledger.database.writer.read { database in
        try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM account")
    }
    #expect(rows == 1)
}

@Test("A bank lists only its own accounts")
func listsAccountsOfOneBank() async throws {
    let ledger = try LedgerOnDisk()
    let bbva = try Institution(name: "BBVA")
    let tradeRepublic = try Institution(name: "Trade Republic")
    try await ledger.institutions.save(bbva)
    try await ledger.institutions.save(tradeRepublic)
    try await ledger.accounts.save(
        Account(institutionID: bbva.id, name: "Nómina", kind: .asset, currency: .eur)
    )
    try await ledger.accounts.save(
        Account(institutionID: tradeRepublic.id, name: "Remunerada", kind: .asset, currency: .eur)
    )
    try await ledger.accounts.save(Account(name: "Efectivo", kind: .asset, currency: .eur))

    let stored = try await ledger.accounts.accounts(inInstitution: bbva.id)

    #expect(stored.map(\.name) == ["Nómina"])
}

@Test("A row that the domain considers impossible fails on read instead of coming through")
func rejectsImpossibleRowOnRead() async throws {
    let ledger = try LedgerOnDisk()

    let bank = UUID().uuidString
    // The pragma removes the schema's net for this connection, standing in for what a bad
    // migration or a rogue import could leave behind.
    try await ledger.database.writer.write { database in
        try database.execute(sql: "PRAGMA ignore_check_constraints = ON")
        try database.execute(
            sql: """
                INSERT INTO institution (id, name, created_at, updated_at)
                VALUES (?, 'BBVA', ?, ?);
                INSERT INTO account
                    (id, institution_id, name, kind, currency_code, created_at, updated_at)
                VALUES (?, ?, 'Supermercado', 'expense', 'EUR', ?, ?);
                """,
            arguments: [
                bank, Date(), Date(),
                UUID().uuidString, bank, Date(), Date(),
            ]
        )
        try database.execute(sql: "PRAGMA ignore_check_constraints = OFF")
    }

    // Account.init is the second net, and it is the one that catches this. Decoding straight
    // into the entity would have let the row through.
    await #expect(throws: AccountError.kindCannotBelongToInstitution(.expense)) {
        try await ledger.accounts.accounts(ofKinds: [.expense])
    }
}
