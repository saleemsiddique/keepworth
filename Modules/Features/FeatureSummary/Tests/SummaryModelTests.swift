import Foundation
import KeepworthDomain
import Testing

@testable import FeatureSummary

/// A ledger with two banks, a loose cash account and a handful of movements.
///
/// Against in-memory doubles of the `Domain` protocols, never a database: the feature layer
/// does not know one exists, and its tests should not either.
@MainActor
private struct Fixture {
    let bbva: Institution
    let tradeRepublic: Institution
    let payroll: Account
    let savings: Account
    let card: Account
    let cash: Account
    let groceries: Account
    let salary: Account
    let institutions: FakeInstitutionRepository
    let accounts: FakeAccountRepository
    let entries: FakeEntryRepository
    let settings: FakeSettingsRepository
    let changes: FakeLedgerChanges

    init() throws {
        bbva = try Institution(name: "BBVA")
        tradeRepublic = try Institution(name: "Trade Republic")
        payroll = try Account(institutionID: bbva.id, name: "Nómina", kind: .asset, currency: .eur)
        savings = try Account(
            institutionID: tradeRepublic.id, name: "Remunerada", kind: .asset, currency: .eur)
        card = try Account(
            institutionID: bbva.id, name: "Visa", kind: .liability, currency: .eur)
        cash = try Account(name: "Efectivo", kind: .asset, currency: .eur)
        groceries = try Account(name: "Supermercado", kind: .expense, currency: .eur)
        salary = try Account(name: "Nómina", kind: .income, currency: .eur)

        changes = FakeLedgerChanges()
        institutions = FakeInstitutionRepository([bbva, tradeRepublic], changes: changes)
        accounts = FakeAccountRepository(
            [payroll, savings, card, cash, groceries, salary], changes: changes)
        entries = FakeEntryRepository(changes: changes)
        settings = FakeSettingsRepository(baseCurrency: .eur, changes: changes)
    }

    func model() -> SummaryModel {
        SummaryModel(
            institutions: institutions,
            accounts: accounts,
            entries: entries,
            settings: settings,
            changes: changes,
            calendar: fixedCalendar,
            now: { instantOfToday }
        )
    }

    func record(income amount: Int64, on day: Int, into account: Account) async throws {
        _ = try await RecordIncome(accounts: accounts, entries: entries).execute(
            RecordIncome.Request(
                accountID: account.id,
                categoryID: salary.id,
                amount: Money(minorUnits: amount, currency: .eur),
                occurredOn: try CalendarDate(year: 2026, month: 1, day: day),
                payee: "Nómina"
            )
        )
    }

    func record(expense amount: Int64, on day: Int, from account: Account) async throws {
        _ = try await RecordExpense(accounts: accounts, entries: entries).execute(
            RecordExpense.Request(
                accountID: account.id,
                categoryID: groceries.id,
                amount: Money(minorUnits: amount, currency: .eur),
                occurredOn: try CalendarDate(year: 2026, month: 1, day: day),
                payee: "Mercadona"
            )
        )
    }
}

/// Fixed so "today" never moves under the tests and a movement dated on the 28th is genuinely
/// in the future.
private let fixedCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

/// Noon on 20 January 2026, UTC. Written as an instant rather than assembled from components
/// so it needs no unwrapping and cannot silently become a different day.
private let instantOfToday = Date(timeIntervalSince1970: 1_768_910_400)

@MainActor
private func snapshot(of model: SummaryModel) async throws -> SummarySnapshot {
    await model.load()
    guard case .ready(let snapshot) = model.state else {
        throw FixtureError.notReady
    }
    return snapshot
}

private enum FixtureError: Error { case notReady }

@MainActor
@Test("Net worth counts money accounts and nothing else")
func netWorthCountsMoneyAccountsOnly() async throws {
    let fixture = try Fixture()
    try await fixture.record(income: 210_000, on: 5, into: fixture.payroll)
    try await fixture.record(expense: 4230, on: 10, from: fixture.payroll)

    let snapshot = try await snapshot(of: fixture.model())

    // 2.100,00 in and 42,30 out. The category the expense was filed under adds nothing: a
    // category that moved net worth would tell the user they have money they do not.
    #expect(snapshot.netWorth == Money(minorUnits: 205_770, currency: .eur))
}

@MainActor
@Test("The headline change equals what the report says the month did")
func headlineChangeMatchesTheReport() async throws {
    let fixture = try Fixture()
    try await fixture.record(income: 210_000, on: 5, into: fixture.payroll)
    try await fixture.record(expense: 4230, on: 10, from: fixture.payroll)

    let snapshot = try await snapshot(of: fixture.model())

    // Taken from the same `PeriodSummary` the report screen shows, so the two cannot disagree
    // — which is the reason the ledger is double entry in the first place.
    #expect(snapshot.monthChange == snapshot.month.netWorthChange)
    #expect(snapshot.monthChange == Money(minorUnits: 205_770, currency: .eur))
}

@MainActor
@Test("Banks come sorted by total, and their accounts by balance")
func banksSortedByTotalAndAccountsByBalance() async throws {
    let fixture = try Fixture()
    try await fixture.record(income: 100_000, on: 2, into: fixture.payroll)
    try await fixture.record(income: 500_000, on: 3, into: fixture.savings)

    let snapshot = try await snapshot(of: fixture.model())

    #expect(snapshot.institutions.map(\.institution.name) == ["Trade Republic", "BBVA"])
    #expect(snapshot.institutions.first?.accounts.map(\.account.name) == ["Remunerada"])
    // BBVA holds the payroll account and the card; the card is at zero, so it comes second.
    #expect(snapshot.institutions.last?.accounts.map(\.account.name) == ["Nómina", "Visa"])
}

@MainActor
@Test("Accounts with no bank are kept apart")
func unbankedAccountsAreKeptApart() async throws {
    let fixture = try Fixture()
    try await fixture.record(income: 12000, on: 4, into: fixture.cash)

    let snapshot = try await snapshot(of: fixture.model())

    #expect(snapshot.unbanked.map(\.account.name) == ["Efectivo"])
    // And never inside a bank, which is what the grouping exists to avoid.
    let banked = snapshot.institutions.flatMap { $0.accounts.map(\.account.name) }
    #expect(!banked.contains("Efectivo"))
}

@MainActor
@Test("Categories never appear among the accounts")
func categoriesNeverAppearAmongAccounts() async throws {
    let fixture = try Fixture()
    try await fixture.record(expense: 4230, on: 10, from: fixture.cash)

    let snapshot = try await snapshot(of: fixture.model())

    let shown =
        snapshot.unbanked.map(\.account.name)
        + snapshot.institutions.flatMap { $0.accounts.map(\.account.name) }
    #expect(!shown.contains("Supermercado"))
}

@MainActor
@Test("An archived account leaves the list")
func archivedAccountLeavesTheList() async throws {
    let fixture = try Fixture()
    try await fixture.accounts.archive(fixture.card.id)

    let snapshot = try await snapshot(of: fixture.model())

    let banked = snapshot.institutions.flatMap { $0.accounts.map(\.account.name) }
    #expect(!banked.contains("Visa"))
}

@MainActor
@Test("A movement dated in the future stays out of today's net worth")
func futureMovementStaysOut() async throws {
    let fixture = try Fixture()
    try await fixture.record(income: 100_000, on: 5, into: fixture.payroll)
    // Today is the 20th in the fixture.
    try await fixture.record(income: 900_000, on: 28, into: fixture.payroll)

    let snapshot = try await snapshot(of: fixture.model())

    #expect(snapshot.netWorth == Money(minorUnits: 100_000, currency: .eur))
}

@MainActor
@Test("The recent block shows the newest movements first")
func recentShowsNewestFirst() async throws {
    let fixture = try Fixture()
    try await fixture.record(expense: 1000, on: 2, from: fixture.cash)
    try await fixture.record(expense: 2000, on: 9, from: fixture.cash)
    try await fixture.record(expense: 3000, on: 15, from: fixture.cash)

    let snapshot = try await snapshot(of: fixture.model())

    #expect(snapshot.recent.map(\.occurredOn.day) == [15, 9, 2])
}

@MainActor
@Test("Category names come through, so a movement can name what it was filed under")
func categoryNamesComeThrough() async throws {
    let fixture = try Fixture()
    try await fixture.record(expense: 4230, on: 10, from: fixture.cash)

    let snapshot = try await snapshot(of: fixture.model())

    // The map has to cover categories, not only the accounts the screen lists. Without them a
    // movement row shows the account twice and never says what it was.
    #expect(snapshot.accountNames[fixture.groceries.id] == "Supermercado")
    #expect(snapshot.accountNames[fixture.cash.id] == "Efectivo")
    // And the money accounts are exactly the ones that hold money.
    #expect(!snapshot.moneyAccountIDs.contains(fixture.groceries.id))
    #expect(snapshot.moneyAccountIDs.contains(fixture.cash.id))
    #expect(snapshot.moneyAccountIDs.contains(fixture.card.id))
}

@MainActor
@Test("A ledger with no base currency fails instead of showing zeroes")
func unseededLedgerFails() async throws {
    let fixture = try Fixture()
    await fixture.settings.forget()

    let model = fixture.model()
    await model.load()

    // Zeroes would read as "you have no money", which is a different statement from "this
    // could not be worked out".
    guard case .failed = model.state else {
        Issue.record("expected the model to report failure")
        return
    }
}

@MainActor
@Test("A write to the ledger reloads the screen without anyone asking")
func aWriteReloadsTheScreen() async throws {
    let fixture = try Fixture()
    let model = fixture.model()
    let watching = Task { await model.observe() }
    defer { watching.cancel() }

    // Wait for the first load, then write behind the screen's back.
    try await waitUntil { if case .ready = model.state { return true } else { return false } }
    try await fixture.record(income: 210_000, on: 5, into: fixture.payroll)

    try await waitUntil {
        guard case .ready(let snapshot) = model.state else { return false }
        return snapshot.netWorth == Money(minorUnits: 210_000, currency: .eur)
    }
}

@MainActor
private func waitUntil(
    _ condition: @MainActor () -> Bool,
    within timeout: Duration = .seconds(2)
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("condition never held")
}
