import KeepworthDomain

/// The places money sits in, as Settings lists them.
///
/// No balances anywhere in here. This screen administers accounts — what they are called, who
/// they belong to, whether they are still in use — and the summary is where they are counted.
/// Loading a figure nobody reads would be work, and a second place for it to disagree.
public struct SettingsSnapshot: Sendable {
    public let banks: [BankedAccounts]
    /// Cash and anything else that belongs to no bank.
    public let unbanked: [Account]
    /// Out of the editor, still in the ledger. Kept apart rather than greyed out in place, so
    /// the list above is exactly what a movement can be recorded against.
    public let archived: [Account]
    /// Banks with no live account left, or that the user put away by hand.
    public let archivedBanks: [Institution]
    /// Every new account is opened in it. There is one currency until multi-currency lands.
    public let baseCurrency: CurrencyCode

    public init(
        banks: [BankedAccounts],
        unbanked: [Account],
        archived: [Account],
        archivedBanks: [Institution],
        baseCurrency: CurrencyCode
    ) {
        self.banks = banks
        self.unbanked = unbanked
        self.archived = archived
        self.archivedBanks = archivedBanks
        self.baseCurrency = baseCurrency
    }

    /// Whether there is any bank to file an account under, which is what decides between
    /// offering the picker and offering to create the first one.
    public var hasBanks: Bool { !banks.isEmpty }
}

/// A bank and the accounts it holds.
public struct BankedAccounts: Sendable, Identifiable {
    public let bank: Institution
    public let accounts: [Account]

    public var id: InstitutionID { bank.id }

    public init(bank: Institution, accounts: [Account]) {
        self.bank = bank
        self.accounts = accounts
    }
}
