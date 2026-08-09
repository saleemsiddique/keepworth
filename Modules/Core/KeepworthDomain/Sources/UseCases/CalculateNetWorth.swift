/// El patrimonio neto a una fecha: lo que tienes menos lo que debes.
///
/// **Solo suma cuentas de activo y de pasivo.** Que una categoría entrara aquí es el bug más
/// grave posible de la app: le diría al usuario que tiene dinero que no tiene.
///
/// El filtro de fecha no es opcional. Un movimiento fechado en el futuro es una previsión:
/// hasta que llega su día, el dinero sigue donde estaba.
public struct CalculateNetWorth: Sendable {
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.entries = entries
    }

    /// - Parameters:
    ///   - date: último día que cuenta. Lo posterior no ha ocurrido todavía.
    ///   - baseCurrency: la divisa del usuario, en la que cuadran todos los asientos.
    public func execute(
        asOf date: CalendarDate, in baseCurrency: CurrencyCode
    ) async throws -> Money {
        let netWorthAccounts = try await accounts.accounts(ofKinds: [.asset, .liability])
        guard !netWorthAccounts.isEmpty else {
            return .zero(in: baseCurrency)
        }

        let lines = try await entries.lines(
            matching: EntryLineQuery(
                accountIDs: Set(netWorthAccounts.map(\.id)),
                through: date
            )
        )
        return try Money.sum(lines.map(\.baseAmount), in: baseCurrency)
    }
}
