/// Mueve dinero entre dos cuentas del usuario.
///
/// No aparece en el informe del mes sin necesidad de excluirlo: sus dos patas son cuentas
/// con dinero, y el informe solo mira categorías. Y el patrimonio no se mueve, porque lo que
/// sale de un lado entra en el otro.
///
/// Un traspaso entre bancos tarda días en llegar, pero no se modela con una cuenta puente:
/// se aplica entero según su fecha. Modelarlo obligaría a un paso más en cada traspaso a
/// cambio de un matiz que la fecha ya resuelve.
public struct TransferBetweenAccounts: Sendable {
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.entries = entries
    }

    public struct Request: Hashable, Sendable {
        public let sourceAccountID: AccountID
        public let destinationAccountID: AccountID
        /// Cuánto se traspasa, en positivo.
        public let amount: Money
        public let occurredOn: CalendarDate
        public let note: String?

        public init(
            sourceAccountID: AccountID,
            destinationAccountID: AccountID,
            amount: Money,
            occurredOn: CalendarDate,
            note: String? = nil
        ) {
            self.sourceAccountID = sourceAccountID
            self.destinationAccountID = destinationAccountID
            self.amount = amount
            self.occurredOn = occurredOn
            self.note = note
        }
    }

    @discardableResult
    public func execute(_ request: Request) async throws -> Entry {
        let source = try await accounts.account(withID: request.sourceAccountID)
        let destination = try await accounts.account(withID: request.destinationAccountID)

        try validateHoldsMoney(source)
        try validateHoldsMoney(destination)
        try validateMovement(of: request.amount, outOf: source, into: destination)

        let entry = try Entry.twoLine(
            occurredOn: request.occurredOn,
            payee: nil,
            note: request.note,
            outOf: source.id,
            into: destination.id,
            amount: request.amount
        )
        try await entries.save(entry)
        return entry
    }
}
