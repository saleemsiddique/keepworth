import Foundation
import KeepworthDomain
import Testing

@testable import FeatureSettings

@MainActor
private struct Fixture {
    let bbva: Institution
    let checking: Account
    let cash: Account
    let groceries: Account
    let openingBalance: Account
    let institutions: FakeInstitutionRepository
    let accounts: FakeAccountRepository
    let entries: FakeEntryRepository
    let settings: FakeSettingsRepository
    let changes: FakeLedgerChanges

    init() throws {
        bbva = try Institution(name: "BBVA")
        checking = try Account(
            institutionID: bbva.id,
            name: "Nómina",
            kind: .asset,
            currency: .eur
        )
        cash = try Account(name: "Efectivo", kind: .asset, currency: .eur)
        groceries = try Account(name: "Supermercado", kind: .expense, currency: .eur)
        openingBalance = try Account(
            name: "Saldo inicial",
            kind: .equity,
            currency: .eur,
            isSystem: true
        )

        changes = FakeLedgerChanges()
        institutions = FakeInstitutionRepository([bbva], changes: changes)
        accounts = FakeAccountRepository(
            [checking, cash, groceries, openingBalance],
            changes: changes
        )
        entries = FakeEntryRepository(changes: changes)
        settings = FakeSettingsRepository(baseCurrency: .eur)
    }

    func model() -> SettingsModel {
        SettingsModel(
            institutions: institutions,
            accounts: accounts,
            settings: settings,
            changes: changes
        )
    }

    func dependencies() -> SettingsDependencies {
        SettingsDependencies(
            institutions: institutions,
            accounts: accounts,
            entries: entries,
            formatter: MoneyFormatter(locale: Locale(identifier: "es_ES"))
        )
    }
}

@MainActor
private func snapshot(of model: SettingsModel) async throws -> SettingsSnapshot {
    await model.load()
    guard case .ready(let snapshot) = model.state else { throw FixtureError.notReady }
    return snapshot
}

private enum FixtureError: Error { case notReady }

@MainActor
@Test("Categories never appear among the accounts")
func categoriesAreNotListed() async throws {
    let fixture = try Fixture()

    let listed = try await snapshot(of: fixture.model())

    let names = (listed.banks.flatMap(\.accounts) + listed.unbanked).map(\.name)
    #expect(names.contains("Nómina"))
    #expect(names.contains("Efectivo"))
    #expect(names.contains("Supermercado") == false)
}

@MainActor
@Test("The opening balance account is not listed, because it is not the user's to manage")
func systemAccountIsNotListed() async throws {
    let fixture = try Fixture()

    let listed = try await snapshot(of: fixture.model())

    let names = (listed.banks.flatMap(\.accounts) + listed.unbanked + listed.archived)
        .map(\.name)
    #expect(names.contains("Saldo inicial") == false)
}

@MainActor
@Test("An account with a bank is listed under it, and cash on its own")
func accountsAreGroupedByBank() async throws {
    let fixture = try Fixture()

    let listed = try await snapshot(of: fixture.model())

    #expect(listed.banks.count == 1)
    #expect(listed.banks.first?.accounts.map(\.name) == ["Nómina"])
    #expect(listed.unbanked.map(\.name) == ["Efectivo"])
}

@MainActor
@Test("An archived account moves to its own section instead of disappearing")
func archivedAccountsAreKeptApart() async throws {
    let fixture = try Fixture()
    let model = fixture.model()

    await model.archive(fixture.cash)

    let listed = try await snapshot(of: model)
    #expect(listed.unbanked.isEmpty)
    #expect(listed.archived.map(\.name) == ["Efectivo"])
}

@MainActor
@Test("Archiving is undoable, so it never reads as deleting")
func archivingIsUndoable() async throws {
    let fixture = try Fixture()
    let model = fixture.model()
    await model.archive(fixture.cash)

    guard case .ready(let archived) = model.state,
        let putAway = archived.archived.first
    else { throw FixtureError.notReady }
    await model.unarchive(putAway)

    let listed = try await snapshot(of: model)
    #expect(listed.archived.isEmpty)
    #expect(listed.unbanked.map(\.name) == ["Efectivo"])
}

@MainActor
@Test("Archiving the opening balance account is refused and said out loud")
func archivingTheSystemAccountIsRefused() async throws {
    let fixture = try Fixture()
    let model = fixture.model()
    await model.load()

    await model.archive(fixture.openingBalance)

    #expect(model.lastFailure == .systemAccount)
    let listed = try await snapshot(of: model)
    #expect(listed.archived.isEmpty)
}

@MainActor
@Test("An archived bank leaves the list keeping the accounts it holds")
func archivingABankKeepsItsAccounts() async throws {
    let fixture = try Fixture()
    let model = fixture.model()

    await model.archive(fixture.bbva)

    let listed = try await snapshot(of: model)
    #expect(listed.banks.isEmpty)
    #expect(listed.archivedBanks.map(\.name) == ["BBVA"])
    // The account is still the user's, and still theirs to see in the summary.
    #expect(try await fixture.accounts.account(withID: fixture.checking.id).isArchived == false)
}

@MainActor
@Test("A ledger with no base currency fails instead of showing an empty screen")
func failsWithoutBaseCurrency() async throws {
    let fixture = try Fixture()
    let model = SettingsModel(
        institutions: fixture.institutions,
        accounts: fixture.accounts,
        settings: FakeSettingsRepository(baseCurrency: nil),
        changes: fixture.changes
    )

    await model.load()

    guard case .failed = model.state else {
        Issue.record("expected the screen to say it could not load")
        return
    }
}
