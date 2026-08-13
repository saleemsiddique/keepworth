/// Creates the accounts a brand-new ledger needs, and records the user's currency.
///
/// Not a migration: it depends on two things only known at run time — the currency the user
/// picks and the language their device is in. Migrations have to be deterministic.
///
/// Category names arrive already translated and **belong to the user from that moment on**:
/// changing the device language later does not rename them. Marking them as "system" and
/// translating on the fly would drag a special case through the whole app and break anyway
/// the first time the user renames one.
public struct SeedFirstLaunch: Sendable {
    private let accounts: any AccountRepository
    private let settings: any SettingsRepository

    public init(accounts: any AccountRepository, settings: any SettingsRepository) {
        self.accounts = accounts
        self.settings = settings
    }

    /// The names to create, already in the device's language.
    public struct Names: Hashable, Sendable {
        public let cash: String
        public let openingBalance: String
        public let expenseCategories: [String]
        public let incomeCategories: [String]

        public init(
            cash: String,
            openingBalance: String,
            expenseCategories: [String],
            incomeCategories: [String]
        ) {
            self.cash = cash
            self.openingBalance = openingBalance
            self.expenseCategories = expenseCategories
            self.incomeCategories = incomeCategories
        }
    }

    public func execute(names: Names, baseCurrency: CurrencyCode) async throws {
        guard try await settings.baseCurrency() == nil else {
            throw SeedError.alreadySeeded
        }
        guard !names.expenseCategories.isEmpty, !names.incomeCategories.isEmpty else {
            throw SeedError.noCategories
        }

        try await accounts.save(
            Account(name: names.cash, kind: .asset, currency: baseCurrency)
        )
        // The one account the user never sees. Without it there is nothing for a starting
        // balance to balance against.
        try await accounts.save(
            Account(
                name: names.openingBalance,
                kind: .equity,
                currency: baseCurrency,
                isSystem: true
            )
        )
        for name in names.expenseCategories {
            try await accounts.save(Account(name: name, kind: .expense, currency: baseCurrency))
        }
        for name in names.incomeCategories {
            try await accounts.save(Account(name: name, kind: .income, currency: baseCurrency))
        }

        // Written last: it is what marks the ledger as seeded, so a failure halfway through
        // leaves the next launch able to try again.
        try await settings.setBaseCurrency(baseCurrency)
    }
}

public enum SeedError: Error, Equatable {
    /// The ledger already has a base currency, so this is not a first launch.
    case alreadySeeded
    /// A ledger with no categories cannot record an expense.
    case noCategories
}
