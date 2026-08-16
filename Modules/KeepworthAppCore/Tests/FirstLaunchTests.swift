import Foundation
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

    try await FirstLaunch.prepareIfNeeded(dependencies, locale: Locale(identifier: "es_ES"))

    #expect(try await dependencies.settings.baseCurrency() == .eur)
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
    try await FirstLaunch.prepareIfNeeded(dependencies, locale: Locale(identifier: "es_ES"))
    let everyKind = Set(AccountKind.allCases)
    let afterFirst = try await dependencies.accounts.accounts(ofKinds: everyKind).count

    // Without the guard this throws `SeedError.alreadySeeded`; with a broken guard it would
    // quietly double every category the user has.
    try await FirstLaunch.prepareIfNeeded(dependencies, locale: Locale(identifier: "es_ES"))

    #expect(try await dependencies.accounts.accounts(ofKinds: everyKind).count == afterFirst)
}

@Test("The seeded names are the ones the device can read")
func seededNamesAreLocalised() async throws {
    let dependencies = try inMemoryDependencies()

    try await FirstLaunch.prepareIfNeeded(dependencies, locale: Locale(identifier: "es_ES"))

    let names = try await dependencies.accounts.accounts(ofKinds: Set(AccountKind.allCases))
        .map(\.name)
    // A missing String Catalog entry comes back as the key itself, which is the failure this
    // catches: `seed.expense.groceries` on screen instead of a category name.
    #expect(names.allSatisfy { !$0.contains("seed.") })
    #expect(Set(names).count == names.count)
}

@Test("The currency comes from the device, and there is always one")
func currencyComesFromTheDevice() {
    #expect(FirstLaunch.currency(of: Locale(identifier: "es_ES")) == .eur)
    #expect(FirstLaunch.currency(of: Locale(identifier: "en_US")) == .usd)
    #expect(FirstLaunch.currency(of: Locale(identifier: "en_GB")) == .gbp)
    // A locale with no currency at all still has to yield one: it is a device someone wants
    // to track money on, and the choice is changeable later.
    #expect(FirstLaunch.currency(of: Locale(identifier: "")) == .eur)
}
