import KeepworthDomain
import Testing

@testable import FeatureTransactions

@MainActor
private struct Fixture {
    let cash: Account
    let card: Account
    let groceries: Account
    let salary: Account
    let accounts: FakeAccountRepository
    let entries: FakeEntryRepository
    let changes: FakeLedgerChanges

    init() throws {
        cash = try Account(name: "Efectivo", kind: .asset, currency: .eur)
        card = try Account(name: "Visa", kind: .liability, currency: .eur)
        groceries = try Account(name: "Supermercado", kind: .expense, currency: .eur)
        salary = try Account(name: "Nómina", kind: .income, currency: .eur)
        changes = FakeLedgerChanges()
        accounts = FakeAccountRepository([cash, card, groceries, salary], changes: changes)
        entries = FakeEntryRepository(changes: changes)
    }

    func model() -> TransactionsModel {
        TransactionsModel(accounts: accounts, entries: entries, changes: changes)
    }

    func spend(_ amount: Int64, on day: Int, payee: String) async throws {
        _ = try await RecordExpense(accounts: accounts, entries: entries).execute(
            RecordExpense.Request(
                accountID: cash.id,
                categoryID: groceries.id,
                amount: Money(minorUnits: amount, currency: .eur),
                occurredOn: try CalendarDate(year: 2026, month: 1, day: day),
                payee: payee
            )
        )
    }

    func earn(_ amount: Int64, on day: Int, payee: String) async throws {
        _ = try await RecordIncome(accounts: accounts, entries: entries).execute(
            RecordIncome.Request(
                accountID: cash.id,
                categoryID: salary.id,
                amount: Money(minorUnits: amount, currency: .eur),
                occurredOn: try CalendarDate(year: 2026, month: 1, day: day),
                payee: payee
            )
        )
    }
}

@MainActor
private func days(of model: TransactionsModel) async throws -> [DayOfMovements] {
    await model.load()
    guard case .ready(let days) = model.state else { throw FixtureError.notReady }
    return days
}

private enum FixtureError: Error { case notReady }

@MainActor
@Test("Movements are grouped under the day they happened, newest day first")
func movementsGroupedByDayNewestFirst() async throws {
    let fixture = try Fixture()
    try await fixture.spend(1000, on: 5, payee: "Mercadona")
    try await fixture.spend(2000, on: 12, payee: "Consum")
    try await fixture.spend(3000, on: 12, payee: "Iberdrola")

    let days = try await days(of: fixture.model())

    #expect(days.map(\.day.day) == [12, 5])
    #expect(days.first?.movements.count == 2)
    #expect(days.last?.movements.count == 1)
}

@MainActor
@Test("Two movements on the same day keep the newest saved first")
func sameDayKeepsNewestSavedFirst() async throws {
    let fixture = try Fixture()
    try await fixture.spend(1000, on: 12, payee: "Primero")
    try await fixture.spend(2000, on: 12, payee: "Segundo")

    let days = try await days(of: fixture.model())

    // The same order SQLite gives with `created_at DESC`. Grouping must not re-sort and
    // quietly disagree with the list the user saw a moment ago.
    #expect(days.first?.movements.map(\.payee) == ["Segundo", "Primero"])
}

@MainActor
@Test("Categories are named so a row can say what a movement was filed under")
func categoriesAreNamed() async throws {
    let fixture = try Fixture()
    try await fixture.spend(4230, on: 9, payee: "Mercadona")

    let model = fixture.model()
    _ = try await days(of: model)

    #expect(model.accountNames[fixture.groceries.id] == "Supermercado")
    #expect(model.moneyAccountIDs.contains(fixture.cash.id))
    // A category holds no money, so it can never be the leg a row reads as "the amount".
    #expect(!model.moneyAccountIDs.contains(fixture.groceries.id))
    #expect(model.moneyAccountIDs.contains(fixture.card.id))
}

@MainActor
@Test("An empty ledger reports no days rather than failing")
func emptyLedgerReportsNoDays() async throws {
    let fixture = try Fixture()

    let days = try await days(of: fixture.model())

    // Empty and broken are different statements, and a finance app must not confuse them.
    #expect(days.isEmpty)
}

@MainActor
@Test("Income and expense end up on opposite sides of the same account")
func incomeAndExpenseSitOnOppositeSides() async throws {
    let fixture = try Fixture()
    try await fixture.earn(210_000, on: 3, payee: "Nómina")
    try await fixture.spend(4230, on: 4, payee: "Mercadona")

    let model = fixture.model()
    let listed = try await days(of: model)

    // The colour a row takes follows this sign, so it is worth pinning here rather than in a
    // view that cannot be asserted on.
    let expense = try #require(listed.first?.movements.first)
    let income = try #require(listed.last?.movements.first)
    #expect(expense.moneyLine(among: model.moneyAccountIDs)?.amount.isNegative == true)
    #expect(income.moneyLine(among: model.moneyAccountIDs)?.amount.isPositive == true)
}

@MainActor
@Test("A write reloads the list without anyone asking")
func aWriteReloadsTheList() async throws {
    let fixture = try Fixture()
    let model = fixture.model()
    let watching = Task { await model.observe() }
    defer { watching.cancel() }

    try await waitUntil { if case .ready = model.state { return true } else { return false } }
    try await fixture.spend(4230, on: 9, payee: "Mercadona")

    try await waitUntil {
        guard case .ready(let days) = model.state else { return false }
        return days.count == 1
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
