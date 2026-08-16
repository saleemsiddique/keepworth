import Foundation
import KeepworthDomain
import Observation

/// Loads what the summary screen shows, and reloads it whenever the ledger moves.
///
/// Takes the protocols `KeepworthDomain` declares, never a concrete repository. That is what
/// lets the tests run against in-memory doubles instead of a database.
@MainActor
@Observable
public final class SummaryModel {
    public enum State: Sendable {
        case loading
        case ready(SummarySnapshot)
        /// Nothing to show, and something to say about it. A finance app that renders a blank
        /// screen on failure looks like an app that says you have nothing.
        case failed
    }

    public private(set) var state: State = .loading

    private let institutions: any InstitutionRepository
    private let accounts: any AccountRepository
    private let entries: any EntryRepository
    private let settings: any SettingsRepository
    private let changes: any LedgerChanges
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    /// How many movements the "recent" block shows. Small on purpose: the full list is one tap
    /// away in Movements, and `EntryQuery` refuses an unbounded read.
    private static let recentCount = 5

    public init(
        institutions: any InstitutionRepository,
        accounts: any AccountRepository,
        entries: any EntryRepository,
        settings: any SettingsRepository,
        changes: any LedgerChanges,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.institutions = institutions
        self.accounts = accounts
        self.entries = entries
        self.settings = settings
        self.changes = changes
        self.calendar = calendar
        self.now = now
    }

    /// Loads once, then again on every ledger change, until the screen goes away.
    public func observe() async {
        await load()
        do {
            for try await _ in changes.changes() {
                await load()
            }
        } catch {
            state = .failed
        }
    }

    public func load() async {
        do {
            state = .ready(try await snapshot())
        } catch {
            state = .failed
        }
    }

    private func snapshot() async throws -> SummarySnapshot {
        guard let baseCurrency = try await settings.baseCurrency() else {
            throw SummaryError.ledgerNotSeeded
        }
        let today = CalendarDate(now(), in: calendar)

        let netWorth = try await CalculateNetWorth(accounts: accounts, entries: entries)
            .execute(asOf: today, in: baseCurrency)
        let month = try await SummarizePeriod(accounts: accounts, entries: entries)
            .execute(from: today.startOfMonth, through: today.endOfMonth, in: baseCurrency)

        let everyAccount = try await accounts.accounts(ofKinds: Set(AccountKind.allCases))
        let moneyAccountIDs = Set(everyAccount.filter { $0.kind.holdsMoney }.map(\.id))

        return SummarySnapshot(
            netWorth: netWorth,
            monthChange: month.netWorthChange,
            institutions: try await institutionBalances(asOf: today, in: baseCurrency),
            unbanked: try await unbankedBalances(asOf: today),
            month: month,
            recent: try await entries.entries(
                matching: try EntryQuery(limit: Self.recentCount)
            ),
            accountNames: Dictionary(
                everyAccount.map { ($0.id, $0.name) },
                uniquingKeysWith: { first, _ in first }
            ),
            moneyAccountIDs: moneyAccountIDs,
            baseCurrency: baseCurrency
        )
    }

    /// Banks by total, and each bank's accounts by balance. Sorted here and not in SQL because
    /// the key is a `Money` that has to be computed first; ordering it in the query would need
    /// an aggregate that does not exist yet.
    private func institutionBalances(
        asOf today: CalendarDate,
        in baseCurrency: CurrencyCode
    ) async throws -> [InstitutionBalance] {
        let total = CalculateInstitutionTotal(
            institutions: institutions,
            accounts: accounts,
            entries: entries
        )

        var found: [InstitutionBalance] = []
        for institution in try await institutions.allInstitutions() {
            let accountsHere = try await accounts.accounts(inInstitution: institution.id)
                .filter { !$0.isArchived }
            // A bank whose accounts were all archived is a bank the user is done with.
            guard !accountsHere.isEmpty else { continue }

            found.append(
                InstitutionBalance(
                    institution: institution,
                    total: try await total.execute(
                        institutionID: institution.id,
                        asOf: today,
                        in: baseCurrency
                    ),
                    accounts: try await balances(of: accountsHere, asOf: today)
                )
            )
        }
        return found.sorted { $0.total.minorUnits > $1.total.minorUnits }
    }

    private func unbankedBalances(asOf today: CalendarDate) async throws -> [AccountBalance] {
        let loose = try await accounts.accounts(ofKinds: [.asset, .liability])
            .filter { $0.institutionID == nil && !$0.isArchived }
        return try await balances(of: loose, asOf: today)
    }

    private func balances(
        of accountsToTotal: [Account],
        asOf today: CalendarDate
    ) async throws -> [AccountBalance] {
        let balance = CalculateAccountBalance(accounts: accounts, entries: entries)

        var results: [AccountBalance] = []
        for account in accountsToTotal {
            results.append(
                AccountBalance(
                    account: account,
                    balance: try await balance.execute(accountID: account.id, asOf: today)
                )
            )
        }
        return results.sorted { $0.balance.minorUnits > $1.balance.minorUnits }
    }
}

public enum SummaryError: Error, Equatable {
    /// No base currency, so the ledger was never seeded. `KeepworthAppCore` does that before
    /// any screen appears, so reaching this means the launch sequence broke.
    case ledgerNotSeeded
}
