extension String {
    /// "BBVA " and "BBVA" are the same bank; storing both leaves two rows where the user
    /// sees one.
    var trimmedForStorage: String {
        String(
            drop(while: \.isWhitespace)
                .reversed()
                .drop(while: \.isWhitespace)
                .reversed()
        )
    }

    /// `nil` when nothing is left, so the UI never has to tell an empty string from an
    /// absent value.
    var trimmedForStorageOrNil: String? {
        let trimmed = trimmedForStorage
        return trimmed.isEmpty ? nil : trimmed
    }
}
