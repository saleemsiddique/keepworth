/// Lo ingresado, lo gastado y lo ahorrado entre dos fechas, desglosado por categoría.
///
/// El caso de uso recibe un rango cualquiera. Que la pantalla abra en el mes en curso es una
/// decisión de la UI, no del dominio: el mismo cálculo sirve para un mes, para unas
/// vacaciones o para el tramo entre dos nóminas que cayeron raras.
///
/// Los traspasos no aparecen aquí sin necesidad de excluirlos: sus dos patas son cuentas con
/// dinero, y esto solo mira categorías. El saldo inicial tampoco, porque su contrapartida es
/// `equity`.
public struct SummarizePeriod: Sendable {
    private let accounts: any AccountRepository
    private let entries: any EntryRepository

    public init(accounts: any AccountRepository, entries: any EntryRepository) {
        self.accounts = accounts
        self.entries = entries
    }

    public func execute(
        from: CalendarDate,
        through: CalendarDate,
        in baseCurrency: CurrencyCode
    ) async throws -> PeriodSummary {
        let categories = try await accounts.accounts(ofKinds: [.expense, .income])
        // `uniquingKeysWith` en vez de `uniqueKeysWithValues`: este último aborta el proceso
        // si el repositorio devolviera dos cuentas con el mismo identificador, y un dato
        // corrupto no debe tumbar la app mientras el usuario mira su informe.
        let kindsByAccount = Dictionary(
            categories.map { ($0.id, $0.kind) },
            uniquingKeysWith: { first, _ in first }
        )

        let lines = try await entries.lines(
            matching: EntryLineQuery(
                accountIDs: Set(categories.map(\.id)),
                from: from,
                through: through
            )
        )

        // Las líneas de gasto son positivas y las de ingreso negativas, porque es de las
        // categorías de ingreso de donde sale el dinero. El informe las enseña en magnitud.
        let expenseLines = lines.filter { kindsByAccount[$0.accountID] == .expense }
        let incomeLines = lines.filter { kindsByAccount[$0.accountID] == .income }

        let declaredOpeningBalances = try await openingBalances(
            from: from,
            through: through,
            in: baseCurrency
        )

        return try PeriodSummary(
            from: from,
            through: through,
            income: try totalsByAccount(incomeLines, in: baseCurrency, negated: true),
            expenses: try totalsByAccount(expenseLines, in: baseCurrency, negated: false),
            openingBalances: declaredOpeningBalances,
            baseCurrency: baseCurrency
        )
    }

    /// El dinero que entró en cuentas del usuario por haber declarado un saldo de partida.
    ///
    /// No es un ingreso —no lo has cobrado, ya lo tenías— así que no aparece en el informe.
    /// Pero sí sube el patrimonio, y por eso hay que conocerlo: sin este dato, lo ahorrado y
    /// la variación del patrimonio no cuadrarían en los periodos en los que se crea una
    /// cuenta, y esa diferencia parecería un bug en vez de lo que es.
    private func openingBalances(
        from: CalendarDate,
        through: CalendarDate,
        in baseCurrency: CurrencyCode
    ) async throws -> Money {
        let openingBalanceAccounts = try await accounts.accounts(ofKinds: [.equity])
        guard !openingBalanceAccounts.isEmpty else {
            return .zero(in: baseCurrency)
        }

        let lines = try await entries.lines(
            matching: EntryLineQuery(
                accountIDs: Set(openingBalanceAccounts.map(\.id)),
                from: from,
                through: through
            )
        )
        // Las líneas de la cuenta de saldo inicial son la contrapartida: salen de ella y
        // entran en la del usuario, así que lo aportado es su suma con el signo cambiado.
        return try Money.sum(lines.map(\.baseAmount), in: baseCurrency).negated()
    }

    private func totalsByAccount(
        _ lines: [EntryLine],
        in baseCurrency: CurrencyCode,
        negated: Bool
    ) throws -> [AccountTotal] {
        let linesByAccount = Dictionary(grouping: lines, by: \.accountID)

        let totals = try linesByAccount.map { accountID, lines in
            let total = try Money.sum(lines.map(\.baseAmount), in: baseCurrency)
            return AccountTotal(accountID: accountID, total: negated ? try total.negated() : total)
        }
        // De mayor a menor: en un informe interesa primero dónde se ha ido el dinero.
        return totals.sorted { $0.total.minorUnits > $1.total.minorUnits }
    }
}

/// Cuánto ha pasado por una categoría en el periodo, en magnitud positiva.
public struct AccountTotal: Hashable, Sendable {
    public let accountID: AccountID
    public let total: Money

    public init(accountID: AccountID, total: Money) {
        self.accountID = accountID
        self.total = total
    }
}

/// El informe de un periodo.
///
/// El informe y el patrimonio son dos lecturas de las mismas líneas, así que **no pueden
/// contradecirse**: `netWorthChange` es exactamente lo que varió el patrimonio entre `from`
/// y `through`. Esa garantía es la razón de ser de la partida doble, y hay un test que la
/// demuestra contra `CalculateNetWorth`.
///
/// Lo ahorrado por sí solo **no** basta para esa igualdad. Si en el periodo se declaró el
/// saldo inicial de una cuenta nueva, el patrimonio sube sin que hayas ingresado nada: ese
/// dinero ya era tuyo. Por eso el informe lo lleva aparte en `openingBalances`, en lugar de
/// mezclarlo con los ingresos —lo que inflaría lo que crees haber cobrado este mes— o de
/// ignorarlo y dejar que las dos cifras discrepen sin explicación.
public struct PeriodSummary: Hashable, Sendable {
    public let from: CalendarDate
    public let through: CalendarDate
    public let income: [AccountTotal]
    public let expenses: [AccountTotal]
    public let baseCurrency: CurrencyCode
    public let totalIncome: Money
    public let totalExpenses: Money
    /// Lo ingresado menos lo gastado. Negativo si se gastó más de lo que entró.
    public let saved: Money
    /// Saldos de partida declarados en el periodo. Cero en un periodo normal.
    public let openingBalances: Money
    /// Lo que varió el patrimonio en el periodo: lo ahorrado más los saldos de partida.
    public let netWorthChange: Money

    /// Los totales se calculan aquí, una vez, en lugar de ser propiedades que lanzan. Una
    /// vista de SwiftUI no puede hacer `try` en su cuerpo, y obligarla a un `try?` por cada
    /// cifra convertiría un error de datos en un hueco en blanco sin explicación.
    public init(
        from: CalendarDate,
        through: CalendarDate,
        income: [AccountTotal],
        expenses: [AccountTotal],
        openingBalances: Money,
        baseCurrency: CurrencyCode
    ) throws {
        self.from = from
        self.through = through
        self.income = income
        self.expenses = expenses
        self.baseCurrency = baseCurrency
        self.openingBalances = openingBalances
        self.totalIncome = try Money.sum(income.map(\.total), in: baseCurrency)
        self.totalExpenses = try Money.sum(expenses.map(\.total), in: baseCurrency)
        self.saved = try totalIncome - totalExpenses
        self.netWorthChange = try saved + openingBalances
    }
}
