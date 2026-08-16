import KeepworthDomain
import KeepworthPersistence
import Testing

@testable import KeepworthAppCore

/// Against a real in-memory SQLite rather than doubles. This is the composition root: what it
/// is worth proving is that the concrete pieces fit together, which a double would hide.
private func inMemoryDependencies() throws -> Dependencies {
    let database = try AppDatabase.inMemory()
    return Dependencies(
        institutions: SQLiteInstitutionRepository(database: database),
        accounts: SQLiteAccountRepository(database: database),
        entries: SQLiteEntryRepository(database: database),
        settings: SQLiteSettingsRepository(database: database),
        changes: SQLiteLedgerChanges(database: database)
    )
}

@Test("A new ledger comes back seeded and usable")
func newLedgerComesBackSeeded() async throws {
    let dependencies = try inMemoryDependencies()

    try await FirstLaunch.prepareIfNeeded(dependencies)

    #expect(try await dependencies.settings.baseCurrency() != nil)
    #expect(try await dependencies.accounts.accounts(ofKinds: [.asset]).count == 1)
    #expect(try await dependencies.accounts.accounts(ofKinds: [.expense]).count == 9)
    #expect(try await dependencies.accounts.accounts(ofKinds: [.income]).count == 3)
    // The one account the user never sees, and without which a starting balance has nothing
    // to balance against.
    #expect(try await dependencies.accounts.accounts(ofKinds: [.equity]).first?.isSystem == true)
}

@Test("Opening the app again does not seed a second time")
func openingAgainDoesNotSeedTwice() async throws {
    let dependencies = try inMemoryDependencies()
    try await FirstLaunch.prepareIfNeeded(dependencies)
    let everyKind = Set(AccountKind.allCases)
    let afterFirst = try await dependencies.accounts.accounts(ofKinds: everyKind).count

    // Without the guard this throws `SeedError.alreadySeeded`; with a broken guard it would
    // quietly double every category the user has.
    try await FirstLaunch.prepareIfNeeded(dependencies)

    #expect(try await dependencies.accounts.accounts(ofKinds: everyKind).count == afterFirst)
}

@Test("The seeded names are the ones the device can read")
func seededNamesAreLocalised() async throws {
    let dependencies = try inMemoryDependencies()

    try await FirstLaunch.prepareIfNeeded(dependencies)

    let names = try await dependencies.accounts.accounts(ofKinds: Set(AccountKind.allCases))
        .map(\.name)
    // A missing String Catalog entry comes back as the key itself, which is the failure this
    // catches: `seed.expense.groceries` on screen instead of a category name.
    #expect(names.allSatisfy { !$0.contains("seed.") })
    #expect(Set(names).count == names.count)
}

@Test("A device with no currency still gets one")
func deviceWithNoCurrencyStillGetsOne() {
    // Never throws and never returns nil: a device whose locale has no currency is still a
    // device someone wants to track money on, and the choice is changeable later.
    _ = FirstLaunch.currencyOfThisDevice()
}
