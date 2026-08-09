extension Entry {
    /// A two-line entry: the amount leaves one account and enters another.
    ///
    /// This is the shape of all three movements the user records. Only the `kind` of the
    /// accounts on each side changes, which is why there are not three constructors.
    ///
    /// Internal on purpose: building a movement always goes through a use case, which is
    /// what validates the account kinds.
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
