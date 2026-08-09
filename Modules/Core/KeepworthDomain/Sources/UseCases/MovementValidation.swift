/// Comprueba que un importe puede moverse entre estas dos cuentas.
///
/// Se valida antes de construir el asiento para que el error diga qué está mal —una cuenta
/// archivada, un importe negativo— en lugar de un genérico «no cuadra».
func validateMovement(of amount: Money, outOf source: Account, into destination: Account) throws {
    guard amount.isPositive else {
        throw MovementError.amountMustBePositive
    }
    guard source.id != destination.id else {
        throw MovementError.sameAccountOnBothSides(source.id)
    }
    try validateAcceptsNewMovements(source)
    try validateAcceptsNewMovements(destination)
    guard source.currency == destination.currency else {
        throw MovementError.currencyMismatch(expected: source.currency, found: destination.currency)
    }
    guard amount.currency == source.currency else {
        throw MovementError.currencyMismatch(expected: source.currency, found: amount.currency)
    }
}

/// Una cuenta archivada sigue en el histórico pero ya no admite movimientos nuevos: por eso
/// se archiva en vez de borrarse cuando tiene movimientos.
private func validateAcceptsNewMovements(_ account: Account) throws {
    guard !account.isArchived else {
        throw MovementError.archivedAccount(account.id)
    }
}

/// Comprueba que una cuenta es de un tipo donde hay dinero de verdad.
func validateHoldsMoney(_ account: Account) throws {
    guard account.kind.holdsMoney else {
        throw MovementError.accountCannotHoldMoney(account.kind)
    }
}

/// Comprueba que una cuenta es una categoría del tipo esperado.
func validateIsCategory(_ account: Account, ofKind expected: AccountKind) throws {
    guard account.kind == expected else {
        throw MovementError.wrongCategoryKind(expected: expected, found: account.kind)
    }
}

public enum MovementError: Error, Equatable {
    /// El usuario introduce cuánto se movió, siempre en positivo. El signo lo pone la
    /// contabilidad según de qué lado esté cada cuenta.
    case amountMustBePositive
    /// Se usó una categoría donde hacía falta una cuenta con dinero. Una categoría no tiene
    /// saldo: solo registra cuánto ha pasado por ella.
    case accountCannotHoldMoney(AccountKind)
    /// Se usó una cuenta o una categoría del tipo equivocado en el lado de la categoría.
    case wrongCategoryKind(expected: AccountKind, found: AccountKind)
    /// Origen y destino son la misma cuenta: no habría movimiento que registrar.
    case sameAccountOnBothSides(AccountID)
    case currencyMismatch(expected: CurrencyCode, found: CurrencyCode)
    /// Una cuenta archivada conserva su histórico pero no admite movimientos nuevos.
    case archivedAccount(AccountID)
    /// Un saldo inicial de cero no es un saldo inicial: no hay nada que registrar.
    case openingBalanceMustNotBeZero
    /// No existe la cuenta interna «Saldo inicial». La crea la semilla del primer arranque,
    /// y sin ella no hay contra qué cuadrar el saldo de partida de una cuenta.
    case missingOpeningBalanceAccount
}
