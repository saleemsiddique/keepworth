import Foundation
import KeepworthDomain
import Testing

@testable import FeatureSettings

/// The form that opens an account. The part worth asserting is the starting balance: it is
/// the one figure this screen writes into the ledger, and its sign is derived rather than
/// asked for.

@MainActor
private struct FormFixture {
    let cash: Account
    let openingBalance: Account
    let accounts: FakeAccountRepository
    let entries: FakeEntryRepository

    init() throws {
        cash = try Account(name: "Efectivo", kind: .asset, currency: .eur)
        openingBalance = try Account(
            name: "Saldo inicial",
            kind: .equity,
            currency: .eur,
            isSystem: true
        )
        accounts = FakeAccountRepository([cash, openingBalance])
        entries = FakeEntryRepository()
    }

    func form(editing account: Account? = nil) -> AccountForm {
        AccountForm(
            editing: account,
            currency: .eur,
            accounts: accounts,
            entries: entries,
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

@MainActor
@Test("An account cannot be saved without a name")
func nameIsRequired() async throws {
    let form = try FormFixture().form()

    #expect(form.availability == .unavailable)
    form.name = "   "
    #expect(form.availability == .unavailable)
    form.name = "Remunerada"
    #expect(form.availability == .available)
}

@MainActor
@Test("What an account already held goes in as money there")
func assetStartingBalanceIsPositive() async throws {
    let fixture = try FormFixture()
    let form = fixture.form()
    form.name = "Remunerada"
    form.kind = .asset
    for digit in [2, 0, 5, 0, 0, 0, 0] {
        form.startingBalance.append(digit)
    }

    #expect(form.typedStartingBalance == Money(minorUnits: 2_050_000, currency: .eur))
    #expect(await form.save())

    let balance = try await CalculateAccountBalance(
        accounts: fixture.accounts,
        entries: fixture.entries
    ).execute(
        accountID: try #require(
            try await fixture.accounts.accounts(ofKinds: [.asset])
                .first { $0.name == "Remunerada" }
        ).id,
        asOf: try CalendarDate(year: 2026, month: 1, day: 31)
    )
    #expect(balance == Money(minorUnits: 2_050_000, currency: .eur))
}

@MainActor
@Test("What a card already held goes in as money owed, with no switch to find")
func liabilityStartingBalanceIsDebt() async throws {
    let fixture = try FormFixture()
    let form = fixture.form()
    form.name = "Visa"
    form.kind = .liability
    for digit in [3, 2, 0, 4, 5] {
        form.startingBalance.append(digit)
    }

    #expect(form.typedStartingBalance == Money(minorUnits: -32045, currency: .eur))
    #expect(await form.save())
}

@MainActor
@Test("An account opened at zero records no movement at all")
func zeroStartingBalanceWritesNothing() async throws {
    let fixture = try FormFixture()
    let form = fixture.form()
    form.name = "Cartera"

    #expect(await form.save())

    #expect(try await fixture.entries.entries(matching: try EntryQuery(limit: 10)).isEmpty)
}

@MainActor
@Test("Correcting an account does not ask for a starting balance again")
func editingDoesNotAskForStartingBalance() async throws {
    let fixture = try FormFixture()

    let opening = fixture.form()
    #expect(opening.asksForStartingBalance)
    #expect(opening.canChooseKind)

    let correcting = fixture.form(editing: fixture.cash)
    #expect(correcting.asksForStartingBalance == false)
    #expect(correcting.canChooseKind == false)
    #expect(correcting.name == "Efectivo")
}

@MainActor
@Test("Correcting an account renames it in place instead of opening a second one")
func editingRenamesInPlace() async throws {
    let fixture = try FormFixture()
    let form = fixture.form(editing: fixture.cash)
    form.name = "Efectivo en casa"

    #expect(await form.save())

    #expect(try await fixture.accounts.account(withID: fixture.cash.id).name == "Efectivo en casa")
    #expect(try await fixture.accounts.accounts(ofKinds: [.asset]).count == 1)
}

@MainActor
@Test("Renaming the opening balance account is refused and said out loud")
func editingTheSystemAccountIsRefused() async throws {
    let fixture = try FormFixture()
    let form = fixture.form(editing: fixture.openingBalance)
    form.name = "Lo que sea"

    #expect(await form.save() == false)
    #expect(form.lastFailure == .systemAccount)
}
