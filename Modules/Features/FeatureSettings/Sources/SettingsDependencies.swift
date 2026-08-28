import Foundation
import KeepworthDomain

/// What the forms inside Settings need to be built, carried as the protocols `KeepworthDomain`
/// declares.
///
/// The list screen makes the forms because it is the one that knows which row was tapped, and
/// this is what lets it do that without holding four repositories itself. `KeepworthAppCore`
/// fills it in with the real implementations, the same way it does for every other screen.
public struct SettingsDependencies: Sendable {
    private let institutions: any InstitutionRepository
    private let accounts: any AccountRepository
    private let entries: any EntryRepository
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    /// The one way `Money` becomes text. Passed down rather than built per screen so every
    /// figure in the app is written the same way.
    public let formatter: MoneyFormatter

    public init(
        institutions: any InstitutionRepository,
        accounts: any AccountRepository,
        entries: any EntryRepository,
        formatter: MoneyFormatter,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.formatter = formatter
        self.institutions = institutions
        self.accounts = accounts
        self.entries = entries
        self.calendar = calendar
        self.now = now
    }

    /// The currency comes from the snapshot the list is already holding, rather than being
    /// captured here: there is one base currency and it is read once, where it is read anyway.
    @MainActor
    public func accountForm(editing account: Account?, currency: CurrencyCode) -> AccountForm {
        AccountForm(
            editing: account,
            currency: currency,
            accounts: accounts,
            entries: entries,
            calendar: calendar,
            now: now
        )
    }

    @MainActor
    public func bankForm(editing bank: Institution?) -> BankForm {
        BankForm(editing: bank, institutions: institutions)
    }
}
