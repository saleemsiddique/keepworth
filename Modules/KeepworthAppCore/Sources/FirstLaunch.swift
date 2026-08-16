import Foundation
import KeepworthDomain

/// Seeds a brand-new ledger, once.
///
/// No welcome screen. The currency comes from the device rather than from a question, because
/// the first thing the app shows should be the user's money, not a form — and someone who
/// guessed wrong changes it in Settings, which is one tap they take once instead of a screen
/// everyone sees once.
public enum FirstLaunch {
    /// The locale is a parameter and not read from inside, so a test can say which one it
    /// means. Reading `Locale.current` in here made the seed depend on the machine running
    /// it: green on a Spanish Mac, red on an American CI runner, and the failure said
    /// `currencyMismatch` rather than "this test is not repeatable".
    public static func prepareIfNeeded(
        _ dependencies: Dependencies,
        locale: Locale = .current
    ) async throws {
        guard try await dependencies.settings.baseCurrency() == nil else { return }

        try await SeedFirstLaunch(
            accounts: dependencies.accounts,
            settings: dependencies.settings
        )
        .execute(names: seedNames(), baseCurrency: currency(of: locale))
    }

    /// Falls back to the euro rather than throwing: a device with no currency in its locale is
    /// still a device someone wants to track money on, and the choice is changeable.
    static func currency(of locale: Locale) -> CurrencyCode {
        guard
            let identifier = locale.currency?.identifier,
            let currency = try? CurrencyCode(identifier.uppercased())
        else {
            return .eur
        }
        return currency
    }

    /// The list lives in `ESTADO.md` §6 and is deliberately without a catch-all "Other": the
    /// junk drawer swallows exactly what the user wanted to understand.
    private static func seedNames() -> SeedFirstLaunch.Names {
        SeedFirstLaunch.Names(
            cash: String(localized: "seed.account.cash", bundle: .module),
            openingBalance: String(localized: "seed.account.openingBalance", bundle: .module),
            expenseCategories: [
                String(localized: "seed.expense.groceries", bundle: .module),
                String(localized: "seed.expense.restaurants", bundle: .module),
                String(localized: "seed.expense.transport", bundle: .module),
                String(localized: "seed.expense.housing", bundle: .module),
                String(localized: "seed.expense.utilities", bundle: .module),
                String(localized: "seed.expense.health", bundle: .module),
                String(localized: "seed.expense.leisure", bundle: .module),
                String(localized: "seed.expense.shopping", bundle: .module),
                String(localized: "seed.expense.subscriptions", bundle: .module),
            ],
            incomeCategories: [
                String(localized: "seed.income.salary", bundle: .module),
                String(localized: "seed.income.interest", bundle: .module),
                String(localized: "seed.income.other", bundle: .module),
            ]
        )
    }
}
