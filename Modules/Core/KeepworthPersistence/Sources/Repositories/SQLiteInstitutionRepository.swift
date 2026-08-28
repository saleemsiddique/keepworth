import Foundation
import GRDB
import KeepworthDomain

public struct SQLiteInstitutionRepository: InstitutionRepository {
    private let database: AppDatabase
    private let now: @Sendable () -> Date

    public init(database: AppDatabase, now: @escaping @Sendable () -> Date = Date.init) {
        self.database = database
        self.now = now
    }

    public func institution(withID id: InstitutionID) async throws -> Institution {
        let record = try await database.writer.read { db in
            try InstitutionRecord
                .filter(sql: "id = ? AND deleted_at IS NULL", arguments: [id.rawValue.uuidString])
                .fetchOne(db)
        }
        guard let record else {
            throw RepositoryError.institutionNotFound(id)
        }
        return try record.toDomain()
    }

    public func allInstitutions() async throws -> [Institution] {
        let records = try await database.writer.read { db in
            try InstitutionRecord
                .filter(sql: "deleted_at IS NULL")
                .order(sql: "name")
                .fetchAll(db)
        }
        return try records.map { try $0.toDomain() }
    }

    public func save(_ institution: Institution) async throws {
        let now = now()
        try await database.writer.write { db in
            let stored = try StoredTimestamps.read(
                db,
                table: InstitutionRecord.databaseTableName,
                id: institution.id.rawValue.uuidString
            )
            try InstitutionRecord(institution, timestamps: stored, updatedAt: now).save(db)
        }
    }

    public func archive(_ id: InstitutionID) async throws {
        try await setArchived(true, on: id)
    }

    public func unarchive(_ id: InstitutionID) async throws {
        try await setArchived(false, on: id)
    }

    private func setArchived(_ isArchived: Bool, on id: InstitutionID) async throws {
        let now = now()
        let updated = try await database.writer.write { db in
            try db.execute(
                sql: """
                    UPDATE institution SET is_archived = ?, updated_at = ?
                    WHERE id = ? AND deleted_at IS NULL
                    """,
                arguments: [isArchived, now, id.rawValue.uuidString]
            )
            return db.changesCount
        }
        guard updated > 0 else {
            throw RepositoryError.institutionNotFound(id)
        }
    }
}
