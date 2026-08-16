import Foundation
import KeepworthDomain
import KeepworthPersistence

/// Everything a screen needs, as the protocols `KeepworthDomain` declares.
///
/// This is the only place in the app that knows a concrete implementation exists. A feature
/// receives `any AccountRepository`, never `SQLiteAccountRepository`, which is what lets it be
/// tested against in-memory doubles.
public struct Dependencies: Sendable {
    public let institutions: any InstitutionRepository
    public let accounts: any AccountRepository
    public let entries: any EntryRepository
    public let settings: any SettingsRepository
    public let changes: any LedgerChanges
    public let formatter: MoneyFormatter

    public init(
        institutions: any InstitutionRepository,
        accounts: any AccountRepository,
        entries: any EntryRepository,
        settings: any SettingsRepository,
        changes: any LedgerChanges,
        formatter: MoneyFormatter = MoneyFormatter()
    ) {
        self.institutions = institutions
        self.accounts = accounts
        self.entries = entries
        self.settings = settings
        self.changes = changes
        self.formatter = formatter
    }
}

extension Dependencies {
    /// The real thing, on the database in the App Group container.
    ///
    /// **Never call this from the main actor.** Opening the database migrates it, and
    /// `SQLiteLedgerChanges` starts an observation that blocks until it can take write
    /// access. `RootView` builds it on a detached task for exactly that reason.
    public static func live() throws -> Dependencies {
        let database = try AppDatabase.inAppGroup(appGroupIdentifier())
        return Dependencies(
            institutions: SQLiteInstitutionRepository(database: database),
            accounts: SQLiteAccountRepository(database: database),
            entries: SQLiteEntryRepository(database: database),
            settings: SQLiteSettingsRepository(database: database),
            changes: SQLiteLedgerChanges(database: database)
        )
    }

    /// Comes from the app's Info.plist, which `Project.swift` fills from the same constant it
    /// uses for the entitlements. Hardcoding it here would be a third copy of a string that
    /// has to match in all of them.
    private static func appGroupIdentifier() throws -> String {
        guard
            let identifier = Bundle.main.object(forInfoDictionaryKey: "KeepworthAppGroup")
                as? String
        else {
            throw LaunchError.missingAppGroupIdentifier
        }
        return identifier
    }
}

public enum LaunchError: Error, Equatable {
    /// `Project.swift` stopped putting `KeepworthAppGroup` in the Info.plist.
    case missingAppGroupIdentifier
}
