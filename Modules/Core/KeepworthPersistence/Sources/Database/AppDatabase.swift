import Foundation
import GRDB

/// The database, already migrated and ready to use.
///
/// The GRDB connection stays inside: callers get this type and the repositories, never a
/// `DatabaseWriter`, a `Row` or a `Record`.
public struct AppDatabase: Sendable {
    let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Migrations.migrator.migrate(writer)
    }

    /// The real database, in the App Group container so the widget can read it too.
    ///
    /// Not in Documents: a widget cannot reach the app's own container.
    public static func inAppGroup(_ identifier: String) throws -> AppDatabase {
        guard
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: identifier
            )
        else {
            throw DatabaseSetupError.appGroupUnavailable(identifier)
        }

        let directory = container.appendingPathComponent("Database", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            // Not `.complete`: that would stop the widget reading while the phone is locked.
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )

        // A pool, not a queue: the widget reads while the app writes.
        return try AppDatabase(
            writer: DatabasePool(
                path: directory.appendingPathComponent("keepworth.sqlite").path,
                configuration: configuration
            )
        )
    }

    /// An empty database that never touches disk, for tests and previews.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(writer: DatabaseQueue(configuration: configuration))
    }

    private static var configuration: Configuration {
        var configuration = Configuration()
        // SQLite defaults this to off, which would let a line point at an account that no
        // longer exists.
        configuration.foreignKeysEnabled = true
        return configuration
    }
}

public enum DatabaseSetupError: Error, Equatable {
    /// The App Group is missing from the entitlements, or not registered for this bundle id.
    case appGroupUnavailable(String)
}
