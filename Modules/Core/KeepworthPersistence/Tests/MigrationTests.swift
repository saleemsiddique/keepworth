import GRDB
import Testing

@testable import KeepworthPersistence

@Test("Every migration applies to an empty database")
func migratesEmptyDatabase() throws {
    let queue = try DatabaseQueue()

    try Migrations.migrator.migrate(queue)

    let applied = try queue.read { try Migrations.migrator.appliedIdentifiers($0) }
    #expect(applied == Set(Migrations.migrator.migrations))
}

@Test("Migrating twice is a no-op rather than an error")
func migratingTwiceIsIdempotent() throws {
    let queue = try DatabaseQueue()
    try Migrations.migrator.migrate(queue)

    try Migrations.migrator.migrate(queue)

    let applied = try queue.read { try Migrations.migrator.appliedIdentifiers($0) }
    #expect(applied.count == Migrations.migrator.migrations.count)
}

@Test("Every migration applies to a database that already holds data")
func migratesDatabaseWithData() throws {
    let queue = try DatabaseQueue()
    try Migrations.migrator.migrate(queue)
    try queue.write { database in
        try database.execute(
            sql: """
                INSERT INTO account (id, name, kind, currency_code, created_at, updated_at)
                VALUES ('a', 'Efectivo', 'asset', 'EUR', '2026-01-01', '2026-01-01');
                """
        )
    }

    try Migrations.migrator.migrate(queue)

    let names = try queue.read { try String.fetchAll($0, sql: "SELECT name FROM account") }
    #expect(names == ["Efectivo"])
}

@Test("A category with a bank is rejected by the schema, not only by the domain")
func schemaRejectsCategoryInsideInstitution() throws {
    let queue = try DatabaseQueue()
    try Migrations.migrator.migrate(queue)

    #expect(throws: DatabaseError.self) {
        try queue.write { database in
            try database.execute(
                sql: """
                    INSERT INTO institution (id, name, created_at, updated_at)
                    VALUES ('bank', 'BBVA', '2026-01-01', '2026-01-01');

                    INSERT INTO account
                        (id, institution_id, name, kind, currency_code, created_at, updated_at)
                    VALUES ('c', 'bank', 'Supermercado', 'expense', 'EUR', '2026-01-01', '2026-01-01');
                    """
            )
        }
    }
}

@Test("An unknown account kind is rejected by the schema")
func schemaRejectsUnknownKind() throws {
    let queue = try DatabaseQueue()
    try Migrations.migrator.migrate(queue)

    #expect(throws: DatabaseError.self) {
        try queue.write { database in
            try database.execute(
                sql: """
                    INSERT INTO account (id, name, kind, currency_code, created_at, updated_at)
                    VALUES ('a', 'Raro', 'savings', 'EUR', '2026-01-01', '2026-01-01');
                    """
            )
        }
    }
}

@Test("The live view hides lines whose entry is deleted, not only deleted lines")
func liveViewFiltersByEntryToo() throws {
    let queue = try DatabaseQueue()
    try Migrations.migrator.migrate(queue)

    try queue.write { database in
        try database.execute(
            sql: """
                INSERT INTO account (id, name, kind, currency_code, created_at, updated_at)
                VALUES ('a', 'Efectivo', 'asset', 'EUR', '2026-01-01', '2026-01-01');

                INSERT INTO entry (id, occurred_on, created_at, updated_at)
                VALUES ('live', '2026-01-10', '2026-01-01', '2026-01-01'),
                       ('dead', '2026-01-11', '2026-01-01', '2026-01-01');
                UPDATE entry SET deleted_at = '2026-01-12' WHERE id = 'dead';

                INSERT INTO entry_line
                    (id, entry_id, account_id, amount_minor, currency_code,
                     base_amount_minor, created_at, updated_at)
                VALUES ('kept', 'live', 'a', 100, 'EUR', 100, '2026-01-01', '2026-01-01'),
                       ('orphan', 'dead', 'a', 500, 'EUR', 500, '2026-01-01', '2026-01-01');
                """
        )
    }

    let visible = try queue.read {
        try String.fetchAll($0, sql: "SELECT id FROM live_entry_line ORDER BY id")
    }

    // 'orphan' is not deleted itself; only its entry is. Querying entry_line directly would
    // still return it and silently unbalance every derived figure.
    #expect(visible == ["kept"])
}

@Test("A line pointing at an account that does not exist is rejected")
func enforcesForeignKeys() throws {
    // Through `AppDatabase` on purpose: this checks our configuration, not SQLite's default,
    // which has foreign keys off.
    let writer = try AppDatabase.inMemory().writer

    #expect(throws: DatabaseError.self) {
        try writer.write { database in
            try database.execute(
                sql: """
                    INSERT INTO entry (id, occurred_on, created_at, updated_at)
                    VALUES ('e', '2026-01-10', '2026-01-01', '2026-01-01');

                    INSERT INTO entry_line
                        (id, entry_id, account_id, amount_minor, currency_code,
                         base_amount_minor, created_at, updated_at)
                    VALUES ('l', 'e', 'ghost', 100, 'EUR', 100, '2026-01-01', '2026-01-01');
                    """
            )
        }
    }
}
