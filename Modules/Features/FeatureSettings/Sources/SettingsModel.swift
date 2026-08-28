import KeepworthDomain
import Observation

/// Loads the accounts and banks Settings lists, and reloads them whenever the ledger moves.
///
/// Takes the protocols `KeepworthDomain` declares, never a concrete repository. That is what
/// lets the tests run against in-memory doubles instead of a database.
@MainActor
@Observable
public final class SettingsModel {
    public enum State: Sendable {
        case loading
        case ready(SettingsSnapshot)
        /// Nothing to show, and something to say about it. A finance app that renders a blank
        /// screen on failure looks like an app that says you have nothing.
        case failed
    }

    public private(set) var state: State = .loading
    /// Set when an action the user just took could not be carried out — archiving the account
    /// every starting balance is booked against, for one. Cleared by the screen once said.
    public private(set) var lastFailure: SettingsFailure?

    private let institutions: any InstitutionRepository
    private let accounts: any AccountRepository
    private let settings: any SettingsRepository
    private let changes: any LedgerChanges

    public init(
        institutions: any InstitutionRepository,
        accounts: any AccountRepository,
        settings: any SettingsRepository,
        changes: any LedgerChanges
    ) {
        self.institutions = institutions
        self.accounts = accounts
        self.settings = settings
        self.changes = changes
    }

    /// Loads once, then again on every ledger change, until the screen goes away.
    public func observe() async {
        // Subscribed **before** the first load, not after. `changes()` registers the listener
        // synchronously, so a write landing between the read and the subscription would go
        // unnoticed until the next one.
        let signals = changes.changes()
        await load()
        do {
            for try await _ in signals {
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

    public func archive(_ account: Account) async {
        await run { try await ArchiveAccount(accounts: accounts).execute(account.id) }
    }

    public func unarchive(_ account: Account) async {
        await run { try await ArchiveAccount(accounts: accounts).unarchive(account.id) }
    }

    public func archive(_ bank: Institution) async {
        await run { try await institutions.archive(bank.id) }
    }

    public func unarchive(_ bank: Institution) async {
        await run { try await institutions.unarchive(bank.id) }
    }

    public func dismissFailure() {
        lastFailure = nil
    }

    /// The write path every one-tap action shares. Reloading by hand rather than waiting for
    /// the change signal: the repositories do ring it, but a screen that only redraws when a
    /// notification arrives is a screen that stays wrong if one is ever missed.
    private func run(_ write: () async throws -> Void) async {
        do {
            try await write()
            await load()
        } catch AccountError.systemAccountCannotChange {
            lastFailure = .systemAccount
        } catch {
            lastFailure = .writeFailed
        }
    }

    private func snapshot() async throws -> SettingsSnapshot {
        guard let baseCurrency = try await settings.baseCurrency() else {
            throw SettingsError.ledgerNotSeeded
        }

        // Only the kinds that hold money. Categories are accounts too, and listing them here
        // beside the bank accounts is exactly the mixing the UI never does.
        let moneyAccounts = try await accounts.accounts(ofKinds: [.asset, .liability])
        let live = moneyAccounts.filter { !$0.isArchived }
        let everyBank = try await institutions.allInstitutions()

        let banks =
            everyBank
            .filter { !$0.isArchived }
            .map { bank in
                BankedAccounts(
                    bank: bank,
                    accounts: live.filter { $0.institutionID == bank.id }
                )
            }

        return SettingsSnapshot(
            banks: banks,
            unbanked: live.filter { $0.institutionID == nil },
            archived: moneyAccounts.filter(\.isArchived),
            archivedBanks: everyBank.filter(\.isArchived),
            baseCurrency: baseCurrency
        )
    }
}

/// Why a one-tap action did not go through. Not an `Error`: the screen shows it and moves on,
/// and there is nothing for a caller to catch.
public enum SettingsFailure: Hashable, Sendable {
    /// "Opening balance" was on the receiving end. It is what every starting balance is booked
    /// against, so it is neither renamed nor archived.
    case systemAccount
    case writeFailed
}

public enum SettingsError: Error, Equatable {
    /// No base currency, so the ledger was never seeded. `KeepworthAppCore` does that before
    /// any screen appears, so reaching this means the launch sequence broke.
    case ledgerNotSeeded
}
