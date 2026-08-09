/// Qué es una cuenta, y por tanto cómo se comporta.
///
/// Es el único dato que decide si algo suma al patrimonio, si puede pertenecer a un banco
/// y si la UI lo enseña como cuenta o como categoría. No hay un tipo `Category`: una
/// categoría es una cuenta `.expense` o `.income`, y eso es lo que hace que gasto, ingreso
/// y traspaso sean la misma operación.
public enum AccountKind: String, CaseIterable, Hashable, Sendable {
    /// Cuentas bancarias, efectivo, carteras. Suma al patrimonio.
    case asset
    /// Tarjetas de crédito, préstamos. Resta del patrimonio.
    case liability
    /// Categoría de gasto. Nunca toca el patrimonio.
    case expense
    /// Categoría de ingreso. Nunca toca el patrimonio.
    case income
    /// Contrapartida del saldo inicial. Interna y oculta.
    case equity

    /// Si el saldo de esta cuenta forma parte del patrimonio neto.
    ///
    /// Que una categoría devolviera `true` aquí es el bug más grave posible de la app:
    /// le diría al usuario que tiene dinero que no tiene.
    public var countsTowardsNetWorth: Bool {
        switch self {
        case .asset, .liability: true
        case .expense, .income, .equity: false
        }
    }

    /// Si es un sitio donde hay dinero de verdad y por tanto tiene saldo.
    ///
    /// El «saldo» de una categoría no es un saldo: es cuánto ha pasado por ella.
    public var holdsMoney: Bool {
        switch self {
        case .asset, .liability: true
        case .expense, .income, .equity: false
        }
    }

    /// Si una cuenta de este tipo puede pertenecer a un banco.
    ///
    /// Se deriva de `holdsMoney` en lugar de repetir la lista: un banco agrupa sitios donde
    /// hay dinero, así que si algún día dejaran de coincidir sería porque la definición de
    /// banco ha cambiado, y eso se decide aquí.
    public var canBelongToInstitution: Bool { holdsMoney }
}
