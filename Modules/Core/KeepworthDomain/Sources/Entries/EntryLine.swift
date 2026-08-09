/// Una pata de un asiento: cuánto se movió y en qué cuenta.
///
/// Lleva dos importes porque son dos datos distintos, no dos vistas del mismo:
/// `amount` es lo que se movió en la divisa de la cuenta, y `baseAmount` lo que valió en
/// la divisa del usuario. En v1 coinciden.
///
/// `baseAmount` **se guarda, no se calcula**. Multiplicar `amount` por un tipo de cambio
/// deja restos de redondeo —con 1 USD = 0,923456 €, una compra de 123,45 USD descuadra en
/// algo más de un céntimo— y con ellos el invariante de suma cero es inalcanzable. El valor
/// en divisa base es el importe que el banco cobró de verdad, y ése es exacto.
public struct EntryLine: Hashable, Sendable, Identifiable {
    public let id: EntryLineID
    public let accountID: AccountID
    /// Lo que se movió, en la divisa de la cuenta. Negativo si sale, positivo si entra.
    public let amount: Money
    /// Lo que valió en la divisa base del usuario, con el mismo signo.
    public let baseAmount: Money
    /// Con tres o más líneas deja de deducirse cuál es el origen, así que se guarda.
    public let sortOrder: Int

    public init(
        id: EntryLineID = EntryLineID(),
        accountID: AccountID,
        amount: Money,
        baseAmount: Money,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.accountID = accountID
        self.amount = amount
        self.baseAmount = baseAmount
        self.sortOrder = sortOrder
    }

    /// Atajo para el caso monodivisa, donde el importe en divisa base es el mismo.
    public init(
        id: EntryLineID = EntryLineID(),
        accountID: AccountID,
        amount: Money,
        sortOrder: Int = 0
    ) {
        self.init(
            id: id,
            accountID: accountID,
            amount: amount,
            baseAmount: amount,
            sortOrder: sortOrder
        )
    }
}
