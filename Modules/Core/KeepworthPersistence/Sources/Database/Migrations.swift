import GRDB

/// The schema, one migration per change.
///
/// **A published migration is never edited**, not even for a typo: devices that already ran
/// it would keep the old schema while new ones get the new one, and nothing would tell them
/// apart. Changing the schema means adding `v2`.
enum Migrations {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // Raw SQL rather than the query builder so this reads exactly like the schema
        // documented in ESTADO.md, which is what it has to match.
        migrator.registerMigration("v1.initialSchema") { database in
            try database.execute(
                sql: """
                    CREATE TABLE institution (
                        id TEXT PRIMARY KEY NOT NULL,
                        name TEXT NOT NULL,
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL,
                        deleted_at TEXT
                    );

                    CREATE TABLE account (
                        id TEXT PRIMARY KEY NOT NULL,
                        institution_id TEXT REFERENCES institution(id),
                        name TEXT NOT NULL,
                        kind TEXT NOT NULL,
                        currency_code TEXT NOT NULL,
                        symbol_name TEXT,
                        is_system INTEGER NOT NULL DEFAULT 0,
                        is_archived INTEGER NOT NULL DEFAULT 0,
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL,
                        deleted_at TEXT,
                        CHECK (kind IN ('asset','liability','income','expense','equity')),
                        CHECK (institution_id IS NULL OR kind IN ('asset','liability'))
                    );

                    CREATE TABLE entry (
                        id TEXT PRIMARY KEY NOT NULL,
                        occurred_on TEXT NOT NULL,
                        payee TEXT,
                        note TEXT,
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL,
                        deleted_at TEXT
                    );

                    CREATE TABLE entry_line (
                        id TEXT PRIMARY KEY NOT NULL,
                        entry_id TEXT NOT NULL REFERENCES entry(id),
                        account_id TEXT NOT NULL REFERENCES account(id),
                        amount_minor INTEGER NOT NULL,
                        currency_code TEXT NOT NULL,
                        base_amount_minor INTEGER NOT NULL,
                        sort_order INTEGER NOT NULL DEFAULT 0,
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL,
                        deleted_at TEXT
                    );

                    CREATE TABLE app_setting (
                        key TEXT PRIMARY KEY NOT NULL,
                        value TEXT NOT NULL,
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL,
                        deleted_at TEXT
                    );

                    -- A line only counts if neither it nor its entry is deleted. Solved once
                    -- here so no query can forget the second half of that condition.
                    CREATE VIEW live_entry_line AS
                    SELECT entry_line.*, entry.occurred_on
                    FROM entry_line
                    JOIN entry ON entry.id = entry_line.entry_id
                    WHERE entry_line.deleted_at IS NULL AND entry.deleted_at IS NULL;

                    -- Partial: the app only ever queries live rows, so dead ones stay out of
                    -- the index instead of making it bigger and slower.
                    CREATE INDEX index_entry_line_on_entry_id
                        ON entry_line(entry_id) WHERE deleted_at IS NULL;
                    CREATE INDEX index_entry_line_on_account_id
                        ON entry_line(account_id) WHERE deleted_at IS NULL;
                    CREATE INDEX index_entry_on_occurred_on
                        ON entry(occurred_on) WHERE deleted_at IS NULL;
                    CREATE INDEX index_account_on_kind
                        ON account(kind) WHERE deleted_at IS NULL;
                    CREATE INDEX index_account_on_institution_id
                        ON account(institution_id) WHERE deleted_at IS NULL;
                    """
            )
        }

        return migrator
    }
}
