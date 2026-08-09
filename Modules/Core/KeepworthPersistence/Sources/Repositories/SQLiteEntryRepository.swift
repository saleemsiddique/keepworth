import Foundation
import GRDB
import KeepworthDomain

public struct SQLiteEntryRepository: EntryRepository {
    private let database: AppDatabase
    private let now: @Sendable () -> Date

    public init(database: AppDatabase, now: @escaping @Sendable () -> Date = Date.init) {
        self.database = database
        self.now = now
    }

    /// The entry and all its lines go in one transaction. A half-written entry is an
    /// unbalanced entry, and there is no state in between where that would be acceptable.
    public func save(_ entry: Entry) async throws {
        let now = now()
        let entryID = entry.id.rawValue.uuidString

        try await database.writer.write { db in
            let stored = try StoredTimestamps.read(
                db,
                table: EntryRecord.databaseTableName,
                id: entryID
            )
            try EntryRecord(entry, timestamps: stored, updatedAt: now).save(db)

            for line in entry.lines {
                let lineID = line.id.rawValue.uuidString
                let storedLine = try StoredTimestamps.read(
                    db,
                    table: EntryLineRecord.databaseTableName,
                    id: lineID
                )
                try EntryLineRecord(
                    line,
                    entryID: entry.id,
                    timestamps: storedLine,
                    updatedAt: now
                ).save(db)
            }

            // Re-saving an entry with fewer lines has to bury the ones it dropped. Left
            // alive they keep a live entry, so `live_entry_line` still returns them and the
            // stored entry stops summing to zero — with no symptom anywhere.
            let keptIDs = entry.lines.map(\.id.rawValue.uuidString)
            let placeholders = keptIDs.map { _ in "?" }.joined(separator: ",")
            var arguments: [any DatabaseValueConvertible] = [now, now, entryID]
            arguments.append(contentsOf: keptIDs)
            try db.execute(
                sql: """
                    UPDATE entry_line SET deleted_at = ?, updated_at = ?
                    WHERE entry_id = ? AND deleted_at IS NULL AND id NOT IN (\(placeholders))
                    """,
                arguments: StatementArguments(arguments)
            )
        }
    }

    public func lines(matching query: EntryLineQuery) async throws -> [EntryLine] {
        guard !query.accountIDs.isEmpty else { return [] }

        return try await database.writer.read { db in
            guard let baseCurrency = try readBaseCurrency(db) else {
                throw RecordError.missingBaseCurrency
            }

            var conditions: [String] = []
            var arguments: [any DatabaseValueConvertible] = []

            let identifiers = query.accountIDs.map(\.rawValue.uuidString)
            let placeholders = identifiers.map { _ in "?" }.joined(separator: ",")
            conditions.append("account_id IN (\(placeholders))")
            arguments.append(contentsOf: identifiers)

            if let from = query.from {
                conditions.append("occurred_on >= ?")
                arguments.append(from.description)
            }
            if let through = query.through {
                conditions.append("occurred_on <= ?")
                arguments.append(through.description)
            }

            // `live_entry_line`, never `entry_line`: the view is what keeps lines of deleted
            // entries out. Filtering on the line alone leaves them in and unbalances every
            // derived figure without a symptom.
            let records = try EntryLineRecord.fetchAll(
                db,
                sql: """
                    SELECT * FROM live_entry_line
                    WHERE \(conditions.joined(separator: " AND "))
                    ORDER BY occurred_on, sort_order
                    """,
                arguments: StatementArguments(arguments)
            )
            return try records.map { try $0.toDomain(baseCurrency: baseCurrency) }
        }
    }
}
