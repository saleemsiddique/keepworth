extension String {
    /// El texto sin espacios ni saltos de línea alrededor.
    ///
    /// Las entidades normalizan así todo texto que reciben: «BBVA » y «BBVA» son el mismo
    /// banco, y guardarlos distintos deja dos filas donde el usuario ve una.
    var trimmedForStorage: String {
        String(
            drop(while: \.isWhitespace)
                .reversed()
                .drop(while: \.isWhitespace)
                .reversed()
        )
    }

    /// El texto normalizado, o `nil` si al normalizarlo no queda nada.
    ///
    /// Un beneficiario vacío no es un beneficiario: se guarda como ausente, no como cadena
    /// vacía, para que la UI no tenga que distinguir entre dos formas de «no hay nada».
    var trimmedForStorageOrNil: String? {
        let trimmed = trimmedForStorage
        return trimmed.isEmpty ? nil : trimmed
    }
}
