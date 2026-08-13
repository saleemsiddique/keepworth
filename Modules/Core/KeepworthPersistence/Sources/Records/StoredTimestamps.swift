import Foundation
import GRDB

/// The timestamps a row already has, so a write does not invent them.
///
/// `created_at` is not this write's business, and **`deleted_at` even less**: clearing it
/// would resurrect a row whose tombstone is the only thing stopping it from coming back on
/// the next sync.
struct StoredTimestamps {
    var createdAt: Date?
    var deletedAt: Date?

    /// - Parameter table: always a `databaseTableName` literal from a record type, never
    ///   anything a user typed.
    static func read(_ db: Database, table: String, id: String) throws -> StoredTimestamps {
        let row = try Row.fetchOne(
            db,
            sql: "SELECT created_at, deleted_at FROM \(table) WHERE id = ?",
            arguments: [id]
        )
        return StoredTimestamps(createdAt: row?["created_at"], deletedAt: row?["deleted_at"])
    }
}
