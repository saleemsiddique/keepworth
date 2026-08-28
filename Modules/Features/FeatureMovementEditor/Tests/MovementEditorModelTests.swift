import Foundation
import KeepworthDomain
import Testing

@testable import FeatureMovementEditor

@MainActor
private struct Fixture {
    let checking: Account
    let cash: Account
    let retired: Account
    let groceries: Account
    let salary: Account
    let openingBalance: Account
    let accounts: FakeAccountRepository
    let entries: FakeEntryRepository
    let settings: FakeSettingsRepository

    init() throws {
        checking = try Account(name: "Nómina", kind: .asset, currency: .eur)
        cash = try Account(name: "Efectivo", kind: .asset, currency: .eur)
        retired = try Account(name: "Vieja", kind: .asset, currency: .eur, isArchived: true)
        groceries = try Account(name: "Supermercado", kind: .expense, currency: .eur)
        salary = try Account(name: "Nómina", kind: .income, currency: .eur)
        openingBalance = try Account(
            name: "Saldo inicial",
            kind: .equity,
            currency: .eur,
            isSystem: true
        )
        accounts = FakeAccountRepository([
            checking, cash, retired, groceries, salary, openingBalance,
        ])
        entries = FakeEntryRepository()
        settings = FakeSettingsRepository(baseCurrency: .eur)
    }

    func model(editing entry: Entry? = nil) -> MovementEditorModel {
        MovementEditorModel(
            editing: entry,
            accounts: accounts,
            entries: entries,
            settings: settings,
            calendar: calendarFixedToUTC,
            now: { instantOfToday }
        )
    }
}

private let calendarFixedToUTC: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

/// 20 January 2026, 12:00 UTC.
private let instantOfToday = Date(timeIntervalSince1970: 1_768_910_400)

private func euros(_ minorUnits: Int64) -> Money {
    Money(minorUnits: minorUnits, currency: .eur)
}

@MainActor
private func loaded(_ model: MovementEditorModel) async -> MovementEditorModel {
    await model.load()
    return model
}

@MainActor
@Test("An archived account is not offered, and the system account never is")
func archivedAndSystemAccountsAreNotOffered() async throws {
    let fixture = try Fixture()

    let model = await loaded(fixture.model())

    let names = model.moneyAccounts.map(\.name)
    #expect(names.contains("Nómina"))
    #expect(names.contains("Efectivo"))
    #expect(names.contains("Vieja") == false)
    #expect(names.contains("Saldo inicial") == false)
}

@MainActor
@Test("The second picker changes with the type, which is why the switch exists")
func counterpartsFollowTheType() async throws {
    let fixture = try Fixture()
    let model = await loaded(fixture.model())
    model.accountID = fixture.checking.id

    model.type = .expense
    #expect(model.counterparts.map(\.name) == ["Supermercado"])

    model.type = .income
    #expect(model.counterparts.map(\.name) == ["Nómina"])

    model.type = .transfer
    // Its own source is left out: the domain rejects both sides being the same account.
    #expect(model.counterparts.map(\.name) == ["Efectivo"])
}

@MainActor
@Test("Changing the type clears the counterpart, so a category is never saved as an account")
func changingTypeClearsTheCounterpart() async throws {
    let fixture = try Fixture()
    let model = await loaded(fixture.model())
    model.accountID = fixture.checking.id
    model.counterpartID = fixture.groceries.id

    model.type = .transfer

    #expect(model.counterpartID == nil)
}

@MainActor
@Test("A movement cannot be saved until it says where the money went")
func availabilityNeedsBothSidesAndAnAmount() async throws {
    let fixture = try Fixture()
    let model = await loaded(fixture.model())

    #expect(model.availability == .unavailable)
    model.amount.append(5)
    #expect(model.availability == .unavailable)
    model.accountID = fixture.checking.id
    #expect(model.availability == .unavailable)
    model.counterpartID = fixture.groceries.id
    #expect(model.availability == .available)
}

@MainActor
@Test("Money going out reads as going out while it is typed")
func expenseAmountShowsAsLeaving() async throws {
    let fixture = try Fixture()
    let model = await loaded(fixture.model())
    for digit in [4, 2, 3, 0] {
        model.amount.append(digit)
    }

    model.type = .expense
    #expect(model.typedAmount == euros(-4230))

    model.type = .income
    #expect(model.typedAmount == euros(4230))
}

@MainActor
@Test("Recording an expense writes a balanced two-line movement")
func recordsAnExpense() async throws {
    let fixture = try Fixture()
    let model = await loaded(fixture.model())
    model.type = .expense
    model.accountID = fixture.checking.id
    model.counterpartID = fixture.groceries.id
    model.payee = "  Mercadona  "
    for digit in [4, 2, 3, 0] {
        model.amount.append(digit)
    }

    #expect(await model.save())

    let saved = try await fixture.entries.entries(matching: try EntryQuery(limit: 10))
    #expect(saved.count == 1)
    #expect(saved.first?.payee == "Mercadona")
    #expect(saved.first?.lines.count == 2)
}

@MainActor
@Test("Correcting a movement rewrites it instead of recording a second one")
func correctingRewritesInPlace() async throws {
    let fixture = try Fixture()
    let original = try await RecordExpense(
        accounts: fixture.accounts,
        entries: fixture.entries
    ).execute(
        RecordExpense.Request(
            accountID: fixture.checking.id,
            categoryID: fixture.groceries.id,
            amount: euros(4230),
            occurredOn: try CalendarDate(year: 2026, month: 1, day: 31),
            payee: "Mercadona"
        )
    )

    let model = await loaded(fixture.model(editing: original))
    #expect(model.isCorrecting)
    #expect(model.type == .expense)
    #expect(model.accountID == fixture.checking.id)
    #expect(model.counterpartID == fixture.groceries.id)
    #expect(model.amount.minorUnits == 4230)
    #expect(model.payee == "Mercadona")

    model.amount.deleteLast()
    #expect(await model.save())

    let saved = try await fixture.entries.entries(matching: try EntryQuery(limit: 10))
    #expect(saved.count == 1)
    #expect(saved.first?.id == original.id)
}

/// The correction that changes what kind of movement it was. It has to end up with two legs,
/// not four, and keep its id.
@MainActor
@Test("A movement corrected into another type keeps its id and stays two-legged")
func correctingAcrossTypes() async throws {
    let fixture = try Fixture()
    let original = try await RecordExpense(
        accounts: fixture.accounts,
        entries: fixture.entries
    ).execute(
        RecordExpense.Request(
            accountID: fixture.checking.id,
            categoryID: fixture.groceries.id,
            amount: euros(4230),
            occurredOn: try CalendarDate(year: 2026, month: 1, day: 31)
        )
    )

    let model = await loaded(fixture.model(editing: original))
    model.type = .transfer
    model.counterpartID = fixture.cash.id

    #expect(await model.save())

    let saved = try await fixture.entries.entries(matching: try EntryQuery(limit: 10))
    #expect(saved.count == 1)
    #expect(saved.first?.id == original.id)
    #expect(saved.first?.lines.count == 2)
    #expect(
        saved.first?.lines.map(\.accountID).contains(fixture.groceries.id) == false
    )
}

@MainActor
@Test("A ledger with no base currency fails instead of showing an editor that cannot save")
func failsWithoutBaseCurrency() async throws {
    let fixture = try Fixture()
    let model = MovementEditorModel(
        accounts: fixture.accounts,
        entries: fixture.entries,
        settings: FakeSettingsRepository(baseCurrency: nil)
    )

    await model.load()

    guard case .failed = model.state else {
        Issue.record("expected the editor to say it could not load")
        return
    }
}
