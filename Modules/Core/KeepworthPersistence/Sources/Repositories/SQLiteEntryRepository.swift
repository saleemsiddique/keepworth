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

    /// Two queries, not one per entry: first which movements match, then every line of those
    /// movements at once.
    public func entries(matching query: EntryQuery) async throws -> [Entry] {
        if let accountIDs = query.accountIDs, accountIDs.isEmpty { return [] }

        return try await database.writer.read { db in
            guard let baseCurrency = try readBaseCurrency(db) else {
                throw RecordError.missingBaseCurrency
            }

            let entryRecords = try matchingEntries(db, query: query)
            guard !entryRecords.isEmpty else { return [] }

            let linesByEntry = try liveLines(
                db,
                entryIDs: entryRecords.map(\.id),
                baseCurrency: baseCurrency
            )

            // `Entry.init` runs here, so an entry whose stored lines no longer sum to zero
            // throws instead of reaching a screen. All of its lines are handed over, not only
            // the ones the account filter matched: a subset would never balance.
            return try entryRecords.map { record in
                try record.toDomain(lines: linesByEntry[record.id] ?? [])
            }
        }
    }

    private func matchingEntries(_ db: Database, query: EntryQuery) throws -> [EntryRecord] {
        var conditions = ["deleted_at IS NULL"]
        var arguments: [any DatabaseValueConvertible] = []

        if let from = query.from {
            conditions.append("occurred_on >= ?")
            arguments.append(from.description)
        }
        if let through = query.through {
            conditions.append("occurred_on <= ?")
            arguments.append(through.description)
        }
        if let accountIDs = query.accountIDs {
            let identifiers = accountIDs.map(\.rawValue.uuidString)
            let placeholders = identifiers.map { _ in "?" }.joined(separator: ",")
            // Through the view, so an entry whose only matching line was buried stops
            // matching too.
            conditions.append(
                "id IN (SELECT entry_id FROM live_entry_line WHERE account_id IN (\(placeholders)))"
            )
            arguments.append(contentsOf: identifiers)
        }

        arguments.append(query.limit)

        // `created_at` breaks the tie because `occurred_on` has no time: several movements on
        // the same day would otherwise come back in whatever order SQLite felt like, and the
        // list would reshuffle itself between launches.
        return try EntryRecord.fetchAll(
            db,
            sql: """
                SELECT * FROM entry
                WHERE \(conditions.joined(separator: " AND "))
                ORDER BY occurred_on DESC, created_at DESC
                LIMIT ?
                """,
            arguments: StatementArguments(arguments)
        )
    }

    private func liveLines(
        _ db: Database,
        entryIDs: [String],
        baseCurrency: CurrencyCode
    ) throws -> [String: [EntryLine]] {
        let placeholders = entryIDs.map { _ in "?" }.joined(separator: ",")
        let records = try EntryLineRecord.fetchAll(
            db,
            sql: """
                SELECT * FROM live_entry_line
                WHERE entry_id IN (\(placeholders))
                ORDER BY sort_order
                """,
            arguments: StatementArguments(entryIDs)
        )

        return try records.reduce(into: [:]) { grouped, record in
            grouped[record.entryID, default: []].append(
                try record.toDomain(baseCurrency: baseCurrency)
            )
        }
    }
}
