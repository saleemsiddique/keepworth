import Foundation
import GRDB
import KeepworthDomain

/// Settings live in a key-value table, but the API is typed: the rest of the app never sees
/// a raw key, so a typo cannot silently read nothing.
public struct SQLiteSettingsRepository: SettingsRepository {
    static let baseCurrencyKey = "base_currency_code"

    private let database: AppDatabase
    private let now: @Sendable () -> Date

    public init(database: AppDatabase, now: @escaping @Sendable () -> Date = Date.init) {
        self.database = database
        self.now = now
    }

    public func baseCurrency() async throws -> CurrencyCode? {
        let stored = try await database.writer.read { db in
            try readBaseCurrency(db)
        }
        return stored
    }

    public func setBaseCurrency(_ currency: CurrencyCode) async throws {
        let now = now()
        try await database.writer.write { db in
            // `created_at` is only written on insert, and `deleted_at` is never touched:
            // the same rule the other tables follow.
            try db.execute(
                sql: """
                    INSERT INTO app_setting (key, value, created_at, updated_at)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(key) DO UPDATE SET value = excluded.value,
                                                   updated_at = excluded.updated_at
                    """,
                arguments: [Self.baseCurrencyKey, currency.value, now, now]
            )
        }
    }
}

/// Shared with `SQLiteEntryRepository`, which needs the base currency to read line amounts
/// and must do it inside its own transaction.
func readBaseCurrency(_ db: Database) throws -> CurrencyCode? {
    let stored = try String.fetchOne(
        db,
        sql: "SELECT value FROM app_setting WHERE key = ? AND deleted_at IS NULL",
        arguments: [SQLiteSettingsRepository.baseCurrencyKey]
    )
    return try stored.map { try CurrencyCode($0) }
}
