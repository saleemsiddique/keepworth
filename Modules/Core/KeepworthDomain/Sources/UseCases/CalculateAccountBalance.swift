/// El saldo de una cuenta a una fecha, en la divisa de esa cuenta.
///
/// Es una consulta, no una columna guardada: el saldo es la suma de las líneas vivas de la
/// cuenta. Guardarlo abriría la puerta a que el saldo y los movimientos dejaran de coincidir.
///
/// En una cuenta de gasto o de ingreso esto no es un saldo, sino cuánto ha pasado por ahí.
public struct CalculateAccountBalance: Sendable {
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.entries = entries
    }

    public func execute(accountID: AccountID, asOf date: CalendarDate) async throws -> Money {
        let account = try await accounts.account(withID: accountID)

        let lines = try await entries.lines(
            matching: EntryLineQuery(accountIDs: [accountID], through: date)
        )
        return try Money.sum(lines.map(\.amount), in: account.currency)
    }
}
