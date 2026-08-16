import FeatureSummary
import Foundation
import KeepworthDomain
import KeepworthPersistence
import Testing

@testable import KeepworthAppCore

/// The summary screen over the **real** repositories.
///
/// Its own tests use in-memory doubles, which is right for a feature. This one exists because
/// the two are only as interchangeable as they are faithful, and a screen that works against
/// doubles and shows nothing against SQLite is the failure that costs the most to find.
@MainActor
@Test("The summary loads over the real repositories")
func summaryLoadsOverRealRepositories() async throws {
    let database = try AppDatabase.inMemory()
    let dependencies = Dependencies(
        institutions: SQLiteInstitutionRepository(database: database),
        accounts: SQLiteAccountRepository(database: database),
        entries: SQLiteEntryRepository(database: database),
        settings: SQLiteSettingsRepository(database: database),
        changes: SQLiteLedgerChanges(database: database)
    )
    try await FirstLaunch.prepareIfNeeded(dependencies)

    let bank = try Institution(name: "BBVA")
    try await dependencies.institutions.save(bank)
    let payroll = try Account(
        institutionID: bank.id, name: "Nómina", kind: .asset, currency: .eur)
    try await dependencies.accounts.save(payroll)
    let salary = try await dependencies.accounts.accounts(ofKinds: [.income])[0]
    _ = try await RecordIncome(
        accounts: dependencies.accounts, entries: dependencies.entries
    ).execute(
        RecordIncome.Request(
            accountID: payroll.id,
            categoryID: salary.id,
            amount: Money(minorUnits: 210_000, currency: .eur),
            occurredOn: CalendarDate(Date(), in: .current),
            payee: "Nómina"
        )
    )

    let model = SummaryModel(
        institutions: dependencies.institutions,
        accounts: dependencies.accounts,
        entries: dependencies.entries,
        settings: dependencies.settings,
        changes: dependencies.changes
    )
    await model.load()

    guard case .ready(let snapshot) = model.state else {
        Issue.record("the summary failed to load over SQLite")
        return
    }
    #expect(snapshot.netWorth == Money(minorUnits: 210_000, currency: .eur))
    #expect(snapshot.institutions.map(\.institution.name) == ["BBVA"])
    #expect(snapshot.recent.count == 1)
}
