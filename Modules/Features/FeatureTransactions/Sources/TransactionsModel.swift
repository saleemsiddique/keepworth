import Foundation
import KeepworthDomain
import Observation

/// The full list of movements, newest first, grouped by the day they happened.
@MainActor
@Observable
public final class TransactionsModel {
    public enum State: Sendable {
        case loading
        case ready([DayOfMovements])
        case failed
    }

    public private(set) var state: State = .loading
    public private(set) var accountNames: [AccountID: String] = [:]
    public private(set) var moneyAccountIDs: Set<AccountID> = []

    private let accounts: any AccountRepository
    private let entries: any EntryRepository
    private let changes: any LedgerChanges

    /// How far back the list reaches in one read. `EntryQuery` refuses an unbounded one, and
    /// paging with a cursor waits until there is a history long enough to need it.
    private static let pageSize = 200

    public init(
        accounts: any AccountRepository,
        entries: any EntryRepository,
        changes: any LedgerChanges
    ) {
        self.accounts = accounts
        self.entries = entries
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
            let everyAccount = try await accounts.accounts(ofKinds: Set(AccountKind.allCases))
            accountNames = Dictionary(
                everyAccount.map { ($0.id, $0.name) },
                uniquingKeysWith: { first, _ in first }
            )
            moneyAccountIDs = Set(everyAccount.filter { $0.kind.holdsMoney }.map(\.id))

            let found = try await entries.entries(
                matching: try EntryQuery(limit: Self.pageSize)
            )
            state = .ready(Self.grouped(found))
        } catch {
            state = .failed
        }
    }

    /// Groups without re-sorting: the repository already returns newest first, and sorting
    /// again here would be a second opinion on an order the tests pin.
    static func grouped(_ entries: [Entry]) -> [DayOfMovements] {
        var days: [DayOfMovements] = []
        for entry in entries {
            if days.last?.day == entry.occurredOn {
                days[days.count - 1].movements.append(entry)
            } else {
                days.append(DayOfMovements(day: entry.occurredOn, movements: [entry]))
            }
        }
        return days
    }
}

public struct DayOfMovements: Sendable, Identifiable {
    public let day: CalendarDate
    public internal(set) var movements: [Entry]

    public var id: CalendarDate { day }
}
