/// Registra un ingreso: el dinero sale de una categoría de ingreso y entra en una cuenta.
///
/// Es la misma operación que un gasto con las cuentas en el otro orden. Que la categoría
/// esté del lado del que sale el dinero no es un truco contable: es lo que hace que el
/// «saldo» de una categoría de ingreso sea cuánto has cobrado por ahí.
public struct RecordIncome: Sendable {
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.entries = entries
    }

    public struct Request: Hashable, Sendable {
        public let accountID: AccountID
        public let categoryID: AccountID
        /// Cuánto se ingresó, en positivo.
        public let amount: Money
        public let occurredOn: CalendarDate
        public let payee: String?
        public let note: String?

        public init(
            accountID: AccountID,
            categoryID: AccountID,
            amount: Money,
            occurredOn: CalendarDate,
            payee: String? = nil,
            note: String? = nil
        ) {
            self.accountID = accountID
            self.categoryID = categoryID
            self.amount = amount
            self.occurredOn = occurredOn
            self.payee = payee
            self.note = note
        }
    }

    @discardableResult
    public func execute(_ request: Request) async throws -> Entry {
        let account = try await accounts.account(withID: request.accountID)
        let category = try await accounts.account(withID: request.categoryID)

        try validateHoldsMoney(account)
        try validateIsCategory(category, ofKind: .income)
        try validateMovement(of: request.amount, outOf: category, into: account)

        let entry = try Entry.twoLine(
            occurredOn: request.occurredOn,
            payee: request.payee,
            note: request.note,
            outOf: category.id,
            into: account.id,
            amount: request.amount
        )
        try await entries.save(entry)
        return entry
    }
}
