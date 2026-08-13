import Foundation
import GRDB
import KeepworthDomain

public struct SQLiteAccountRepository: AccountRepository {
    private let database: AppDatabase
    private let now: @Sendable () -> Date

    /// `now` is injectable so tests can pin timestamps instead of racing the clock.
    public init(database: AppDatabase, now: @escaping @Sendable () -> Date = Date.init) {
        self.database = database
        self.now = now
    }

    public func account(withID id: AccountID) async throws -> Account {
        let record = try await database.writer.read { db in
            try AccountRecord
                .filter(sql: "id = ? AND deleted_at IS NULL", arguments: [id.rawValue.uuidString])
                .fetchOne(db)
        }
        guard let record else {
            throw RepositoryError.accountNotFound(id)
        }
        return try record.toDomain()
    }

    public func accounts(ofKinds kinds: Set<AccountKind>) async throws -> [Account] {
        guard !kinds.isEmpty else { return [] }
        let wanted = kinds.map(\.rawValue)
        let placeholders = wanted.map { _ in "?" }.joined(separator: ",")

        let records = try await database.writer.read { db in
            try AccountRecord
                .filter(
                    sql: "kind IN (\(placeholders)) AND deleted_at IS NULL",
                    arguments: StatementArguments(wanted)
                )
                .order(sql: "name")
                .fetchAll(db)
        }
        return try records.map { try $0.toDomain() }
    }

    public func accounts(inInstitution id: InstitutionID) async throws -> [Account] {
        let records = try await database.writer.read { db in
            try AccountRecord
                .filter(
                    sql: "institution_id = ? AND deleted_at IS NULL",
                    arguments: [id.rawValue.uuidString]
                )
                .order(sql: "name")
                .fetchAll(db)
        }
        return try records.map { try $0.toDomain() }
    }

    public func save(_ account: Account) async throws {
        let now = now()
        try await database.writer.write { db in
            let stored = try StoredTimestamps.read(
                db,
                table: AccountRecord.databaseTableName,
                id: account.id.rawValue.uuidString
            )
            try AccountRecord(account, timestamps: stored, updatedAt: now).save(db)
        }
    }

    public func archive(_ id: AccountID) async throws {
        let now = now()
        let updated = try await database.writer.write { db in
            try db.execute(
                sql: """
                    UPDATE account SET is_archived = 1, updated_at = ?
                    WHERE id = ? AND deleted_at IS NULL
                    """,
                arguments: [now, id.rawValue.uuidString]
            )
            return db.changesCount
        }
        guard updated > 0 else {
            throw RepositoryError.accountNotFound(id)
        }
    }
}
