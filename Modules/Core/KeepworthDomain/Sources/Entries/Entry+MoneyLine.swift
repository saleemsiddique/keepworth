extension Entry {
    /// The leg that moved an account the user keeps money in — the one they read as "the
    /// amount".
    ///
    /// A movement has a leg on an account and a leg on a category, the same number with
    /// opposite signs. Which of the two is "the amount" is an accounting question, not a
    /// drawing one, so it is answered here and both screens ask rather than each deciding.
    ///
    /// A transfer has **two** money legs and no category. The negative one wins: the money
    /// left there, and a transfer read as an arrival hides where it came from.
    public func moneyLine(among moneyAccountIDs: Set<AccountID>) -> EntryLine? {
        let moneyLines = lines.filter { moneyAccountIDs.contains($0.accountID) }
        return moneyLines.first(where: \.amount.isNegative) ?? moneyLines.first
    }

    /// The leg on the other side: the category a movement was filed under, or the account a
    /// transfer arrived in. `nil` when the entry has more than two legs, where "the other
    /// side" stops being one thing.
    public func counterpartLine(of line: EntryLine) -> EntryLine? {
        guard lines.count == 2 else { return nil }
        return lines.first { $0.id != line.id }
    }
}
