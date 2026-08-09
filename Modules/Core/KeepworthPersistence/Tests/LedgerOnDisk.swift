import Foundation
import GRDB
import KeepworthDomain

@testable import KeepworthPersistence

/// A seeded in-memory ledger with the four repositories wired to it.
///
/// In memory on purpose: these tests must never touch a real file, and an empty database per
/// test is what keeps them independent.
struct LedgerOnDisk {
    let database: AppDatabase
    let accounts: SQLiteAccountRepository
    let institutions: SQLiteInstitutionRepository
    let entries: SQLiteEntryRepository
    let settings: SQLiteSettingsRepository

    /// Pinned so a test can assert on timestamps instead of racing the clock.
    static let creationDate = Date(timeIntervalSince1970: 1_767_225_600)

    init(now: @escaping @Sendable () -> Date = { LedgerOnDisk.creationDate }) throws {
        database = try AppDatabase.inMemory()
        accounts = SQLiteAccountRepository(database: database, now: now)
        institutions = SQLiteInstitutionRepository(database: database, now: now)
        entries = SQLiteEntryRepository(database: database, now: now)
        settings = SQLiteSettingsRepository(database: database, now: now)
    }

    /// Runs the real first-launch seed, so the tests exercise the path the app takes.
    func seed(baseCurrency: CurrencyCode = .eur) async throws {
        try await SeedFirstLaunch(accounts: accounts, settings: settings)
            .execute(
                names: SeedFirstLaunch.Names(
                    cash: "Efectivo",
                    openingBalance: "Saldo inicial",
                    expenseCategories: ["Supermercado", "Vivienda"],
                    incomeCategories: ["Nómina"]
                ),
                baseCurrency: baseCurrency
            )
    }

    func account(named name: String) async throws -> Account {
        let everyKind = Set(AccountKind.allCases)
        let matches = try await accounts.accounts(ofKinds: everyKind).filter { $0.name == name }
        guard let account = matches.first else {
            throw TestLedgerError.noAccountNamed(name)
        }
        return account
    }
}

enum TestLedgerError: Error {
    case noAccountNamed(String)
}

func euros(_ minorUnits: Int64) -> Money {
    Money(minorUnits: minorUnits, currency: .eur)
}

func day(_ year: Int, _ month: Int, _ day: Int) throws -> CalendarDate {
    try CalendarDate(year: year, month: month, day: day)
}
