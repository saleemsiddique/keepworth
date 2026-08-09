/// Da a una cuenta el saldo que ya tenía cuando el usuario empezó a usar la app.
///
/// La pantalla de crear cuenta lo pide siempre: si no, el patrimonio está mal desde el primer
/// minuto y el usuario no sabe por qué.
///
/// Su contrapartida es la cuenta interna `equity` («Saldo inicial»), no una categoría de
/// ingreso. Es lo que hace que el saldo inicial **no contamine el informe del periodo**: no
/// has ingresado 20.000 €, es dinero que ya tenías.
///
/// Admite saldo negativo, que es el caso normal de una tarjeta de crédito con deuda o de una
/// cuenta en números rojos. Por eso no reutiliza la validación de importe positivo de los
/// movimientos: aquí el signo lo elige el usuario, no la contabilidad.
public struct SetOpeningBalance: Sendable {
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.entries = entries
    }

    public struct Request: Hashable, Sendable {
        public let accountID: AccountID
        /// El saldo que la cuenta ya tenía. Negativo si es una deuda.
        public let balance: Money
        public let occurredOn: CalendarDate

        public init(accountID: AccountID, balance: Money, occurredOn: CalendarDate) {
            self.accountID = accountID
            self.balance = balance
            self.occurredOn = occurredOn
        }
    }

    @discardableResult
    public func execute(_ request: Request) async throws -> Entry {
        let account = try await accounts.account(withID: request.accountID)
        let openingBalanceAccount = try await systemOpeningBalanceAccount()

        try validateHoldsMoney(account)
        guard !account.isArchived else {
            throw MovementError.archivedAccount(account.id)
        }
        guard request.balance.currency == account.currency else {
            throw MovementError.currencyMismatch(
                expected: account.currency,
                found: request.balance.currency
            )
        }
        guard !request.balance.isZero else {
            throw MovementError.openingBalanceMustNotBeZero
        }

        // Un saldo positivo entra en la cuenta; uno negativo sale de ella. En ambos casos la
        // contrapartida es la cuenta de saldo inicial, y el asiento cuadra igual.
        let entry =
            request.balance.isPositive
            ? try Entry.twoLine(
                occurredOn: request.occurredOn,
                payee: nil,
                note: nil,
                outOf: openingBalanceAccount.id,
                into: account.id,
                amount: request.balance
            )
            : try Entry.twoLine(
                occurredOn: request.occurredOn,
                payee: nil,
                note: nil,
                outOf: account.id,
                into: openingBalanceAccount.id,
                amount: try request.balance.negated()
            )
        try await entries.save(entry)
        return entry
    }

    private func systemOpeningBalanceAccount() async throws -> Account {
        let equityAccounts = try await accounts.accounts(ofKinds: [.equity])
        guard let openingBalance = equityAccounts.first(where: \.isSystem) else {
            throw MovementError.missingOpeningBalanceAccount
        }
        return openingBalance
    }
}
