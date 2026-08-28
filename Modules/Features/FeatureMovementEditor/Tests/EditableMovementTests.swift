import KeepworthDomain
import Testing

@testable import FeatureMovementEditor

/// Reading a stored movement back into the fields the editor shows. The ledger keeps two
/// balanced legs and no notion of "expense"; these fix the translation back.

@MainActor
private struct Ledger {
    let checking: Account
    let card: Account
    let cash: Account
    let groceries: Account
    let salary: Account
    let openingBalance: Account
    let accounts: FakeAccountRepository
    let entries: FakeEntryRepository

    init() throws {
        checking = try Account(name: "Nómina", kind: .asset, currency: .eur)
        card = try Account(name: "Visa", kind: .liability, currency: .eur)
        cash = try Account(name: "Efectivo", kind: .asset, currency: .eur)
        groceries = try Account(name: "Supermercado", kind: .expense, currency: .eur)
        salary = try Account(name: "Nómina", kind: .income, currency: .eur)
        openingBalance = try Account(
            name: "Saldo inicial",
            kind: .equity,
            currency: .eur,
            isSystem: true
        )
        accounts = FakeAccountRepository([checking, card, cash, groceries, salary, openingBalance])
        entries = FakeEntryRepository()
    }

    var kinds: [AccountID: AccountKind] {
        [
            checking.id: .asset,
            card.id: .liability,
            cash.id: .asset,
            groceries.id: .expense,
            salary.id: .income,
            openingBalance.id: .equity,
        ]
    }
}

private func euros(_ minorUnits: Int64) -> Money {
    Money(minorUnits: minorUnits, currency: .eur)
}

@MainActor
@Test("An expense reads back as an expense, from the account it left")
func readsBackAnExpense() async throws {
    let ledger = try Ledger()
    let entry = try await RecordExpense(
        accounts: ledger.accounts,
        entries: ledger.entries
    ).execute(
        RecordExpense.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.groceries.id,
            amount: euros(4230),
            occurredOn: try CalendarDate(year: 2026, month: 1, day: 31),
            payee: "Mercadona"
        )
    )

    let editable = try #require(EditableMovement(entry: entry, kinds: ledger.kinds))

    #expect(editable.type == .expense)
    #expect(editable.accountID == ledger.checking.id)
    #expect(editable.counterpartID == ledger.groceries.id)
    #expect(editable.minorUnits == 4230)
    #expect(editable.payee == "Mercadona")
}

@MainActor
@Test("Income reads back with the account on the receiving side")
func readsBackIncome() async throws {
    let ledger = try Ledger()
    let entry = try await RecordIncome(
        accounts: ledger.accounts,
        entries: ledger.entries
    ).execute(
        RecordIncome.Request(
            accountID: ledger.checking.id,
            categoryID: ledger.salary.id,
            amount: euros(210_000),
            occurredOn: try CalendarDate(year: 2026, month: 1, day: 25)
        )
    )

    let editable = try #require(EditableMovement(entry: entry, kinds: ledger.kinds))

    #expect(editable.type == .income)
    #expect(editable.accountID == ledger.checking.id)
    #expect(editable.counterpartID == ledger.salary.id)
    #expect(editable.minorUnits == 210_000)
}

@MainActor
@Test("A transfer reads back from the account the money left")
func readsBackATransfer() async throws {
    let ledger = try Ledger()
    let entry = try await TransferBetweenAccounts(
        accounts: ledger.accounts,
        entries: ledger.entries
    ).execute(
        TransferBetweenAccounts.Request(
            sourceAccountID: ledger.checking.id,
            destinationAccountID: ledger.cash.id,
            amount: euros(50000),
            occurredOn: try CalendarDate(year: 2026, month: 2, day: 1)
        )
    )

    let editable = try #require(EditableMovement(entry: entry, kinds: ledger.kinds))

    #expect(editable.type == .transfer)
    #expect(editable.accountID == ledger.checking.id)
    #expect(editable.counterpartID == ledger.cash.id)
}

@MainActor
@Test("A card payment reads back as an expense, not as a transfer")
func readsBackACardPayment() async throws {
    let ledger = try Ledger()
    let entry = try await RecordExpense(
        accounts: ledger.accounts,
        entries: ledger.entries
    ).execute(
        RecordExpense.Request(
            accountID: ledger.card.id,
            categoryID: ledger.groceries.id,
            amount: euros(6000),
            occurredOn: try CalendarDate(year: 2026, month: 1, day: 10)
        )
    )

    let editable = try #require(EditableMovement(entry: entry, kinds: ledger.kinds))

    #expect(editable.type == .expense)
    #expect(editable.accountID == ledger.card.id)
}

/// The one that keeps the editor from turning a starting balance into something else: its
/// counterpart is the internal equity account, which appears in no picker.
@MainActor
@Test("A starting balance cannot be read back, so the editor never opens it")
func refusesAStartingBalance() async throws {
    let ledger = try Ledger()
    let entry = try await SetOpeningBalance(
        accounts: ledger.accounts,
        entries: ledger.entries
    ).execute(
        SetOpeningBalance.Request(
            accountID: ledger.checking.id,
            balance: euros(2_050_000),
            occurredOn: try CalendarDate(year: 2026, month: 1, day: 1)
        )
    )

    #expect(EditableMovement(entry: entry, kinds: ledger.kinds) == nil)
}

@MainActor
@Test("A movement with more than two legs cannot be read back either")
func refusesAThreeLeggedMovement() async throws {
    let ledger = try Ledger()
    let entry = try Entry(
        occurredOn: try CalendarDate(year: 2026, month: 1, day: 5),
        lines: [
            EntryLine(accountID: ledger.checking.id, amount: euros(-10000)),
            EntryLine(accountID: ledger.groceries.id, amount: euros(6000)),
            EntryLine(accountID: ledger.salary.id, amount: euros(4000)),
        ]
    )

    #expect(EditableMovement(entry: entry, kinds: ledger.kinds) == nil)
}
