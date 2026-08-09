/// Registra un gasto: el dinero sale de una cuenta y se imputa a una categoría de gasto.
///
/// El usuario introduce «42,30 en Supermercado desde BBVA» y esto lo traduce en el asiento
/// de dos líneas que hace que el patrimonio y el informe del mes no puedan contradecirse.
/// La UI nunca compone líneas a mano.
public struct RecordExpense: Sendable {
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.entries = entries
    }

    public struct Request: Hashable, Sendable {
        public let accountID: AccountID
        public let categoryID: AccountID
        /// Cuánto se gastó, en positivo.
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
        try validateIsCategory(category, ofKind: .expense)
        try validateMovement(of: request.amount, outOf: account, into: category)

        let entry = try Entry.twoLine(
            occurredOn: request.occurredOn,
            payee: request.payee,
            note: request.note,
            outOf: account.id,
            into: category.id,
            amount: request.amount
        )
        try await entries.save(entry)
        return entry
    }
}
