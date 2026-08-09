extension Entry {
    /// Un asiento de dos líneas: el importe sale de una cuenta y entra en otra.
    ///
    /// Es la forma de **los tres** movimientos que el usuario registra. Un gasto sale de la
    /// cuenta y entra en una categoría de gasto; un ingreso sale de una categoría de ingreso
    /// y entra en la cuenta; un traspaso sale de una cuenta y entra en otra. Lo único que
    /// cambia es el `kind` de las cuentas de cada lado, y por eso no hacen falta tres
    /// constructores distintos.
    ///
    /// En v1 el importe en divisa base coincide con el de la cuenta, porque ambas comparten
    /// divisa. Cuando se abra multi-divisa, aquí es donde entrará el importe en divisa base
    /// como dato aparte.
    static func twoLine(
        occurredOn: CalendarDate,
        payee: String?,
        note: String?,
        outOf source: AccountID,
        into destination: AccountID,
        amount: Money
    ) throws -> Entry {
        try Entry(
            occurredOn: occurredOn,
            payee: payee,
            note: note,
            lines: [
                EntryLine(accountID: source, amount: try amount.negated(), sortOrder: 0),
                EntryLine(accountID: destination, amount: amount, sortOrder: 1),
            ]
        )
    }
}
