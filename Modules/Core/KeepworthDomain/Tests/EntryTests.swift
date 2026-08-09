import Testing

@testable import KeepworthDomain

/// Un gasto de 42,30 € en el súper, tal como lo construye el caso de uso.
private func groceryExpenseLines(
    account: AccountID,
    category: AccountID
) -> [EntryLine] {
    [
        EntryLine(accountID: account, amount: Money(minorUnits: -4230, currency: .eur)),
        EntryLine(accountID: category, amount: Money(minorUnits: 4230, currency: .eur)),
    ]
}

@Test("Un asiento cuyas líneas suman cero se acepta")
func acceptsBalancedEntry() throws {
    let lines = groceryExpenseLines(account: AccountID(), category: AccountID())

    let entry = try Entry(
        occurredOn: CalendarDate(year: 2026, month: 1, day: 31),
        payee: "Mercadona",
        lines: lines
    )

    #expect(entry.lines.count == 2)
    #expect(entry.payee == "Mercadona")
}

@Test("Un asiento cuyas líneas no suman cero se rechaza")
func rejectsUnbalancedEntry() throws {
    let lines = [
        EntryLine(accountID: AccountID(), amount: Money(minorUnits: -4230, currency: .eur)),
        EntryLine(accountID: AccountID(), amount: Money(minorUnits: 4200, currency: .eur)),
    ]

    #expect(throws: EntryError.unbalanced(residual: Money(minorUnits: -30, currency: .eur))) {
        try Entry(occurredOn: CalendarDate(year: 2026, month: 1, day: 31), lines: lines)
    }
}

@Test("Un asiento de una sola línea se rechaza")
func rejectsSingleLineEntry() throws {
    let lines = [
        EntryLine(accountID: AccountID(), amount: Money.zero(in: .eur))
    ]

    #expect(throws: EntryError.needsAtLeastTwoLines(found: 1)) {
        try Entry(occurredOn: CalendarDate(year: 2026, month: 1, day: 31), lines: lines)
    }
}

@Test("Un asiento sin líneas se rechaza")
func rejectsEntryWithoutLines() throws {
    #expect(throws: EntryError.needsAtLeastTwoLines(found: 0)) {
        try Entry(occurredOn: CalendarDate(year: 2026, month: 1, day: 31), lines: [])
    }
}

@Test("Un asiento con divisas base distintas se rechaza")
func rejectsMixedBaseCurrencies() throws {
    let lines = [
        EntryLine(accountID: AccountID(), amount: Money(minorUnits: -100, currency: .eur)),
        EntryLine(accountID: AccountID(), amount: Money(minorUnits: 100, currency: .usd)),
    ]

    #expect(throws: EntryError.mixedBaseCurrencies) {
        try Entry(occurredOn: CalendarDate(year: 2026, month: 1, day: 31), lines: lines)
    }
}

@Test("Un asiento de tres líneas cuadra si el total en divisa base es cero")
func acceptsThreeLineEntry() throws {
    // Venta de 0,5 BTC comprados por 30.000 € y vendidos por 35.000: la ganancia es la
    // tercera línea, y sin ella el asiento no cuadraría.
    let lines = [
        EntryLine(
            accountID: AccountID(),
            amount: Money(minorUnits: -50_000_000, currency: .eur),
            baseAmount: Money(minorUnits: -3_000_000, currency: .eur)
        ),
        EntryLine(
            accountID: AccountID(),
            amount: Money(minorUnits: 3_500_000, currency: .eur),
            baseAmount: Money(minorUnits: 3_500_000, currency: .eur)
        ),
        EntryLine(
            accountID: AccountID(),
            amount: Money(minorUnits: -500_000, currency: .eur),
            baseAmount: Money(minorUnits: -500_000, currency: .eur)
        ),
    ]

    let entry = try Entry(occurredOn: CalendarDate(year: 2026, month: 1, day: 31), lines: lines)

    #expect(entry.lines.count == 3)
}

@Test("El asiento cuadra por el importe en divisa base, no por el de la cuenta")
func balancesByBaseAmountNotAccountAmount() throws {
    // Las dos líneas mueven cantidades distintas en sus divisas —0,5 BTC contra 30.000 €—
    // pero el mismo valor en divisa base, que es lo que tiene que cuadrar.
    let lines = [
        EntryLine(
            accountID: AccountID(),
            amount: Money(minorUnits: -3_000_000, currency: .eur),
            baseAmount: Money(minorUnits: -3_000_000, currency: .eur)
        ),
        EntryLine(
            accountID: AccountID(),
            amount: Money(minorUnits: 50_000_000, currency: .usd),
            baseAmount: Money(minorUnits: 3_000_000, currency: .eur)
        ),
    ]

    let entry = try Entry(occurredOn: CalendarDate(year: 2026, month: 1, day: 31), lines: lines)

    #expect(entry.baseCurrency == .eur)
}

@Test("Un beneficiario en blanco se guarda como ausente")
func storesBlankPayeeAsAbsent() throws {
    let lines = groceryExpenseLines(account: AccountID(), category: AccountID())

    let entry = try Entry(
        occurredOn: CalendarDate(year: 2026, month: 1, day: 31),
        payee: "   ",
        lines: lines
    )

    #expect(entry.payee == nil)
}
