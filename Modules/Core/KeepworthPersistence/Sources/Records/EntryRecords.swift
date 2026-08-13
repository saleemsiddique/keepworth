import Foundation
import GRDB
import KeepworthDomain

/// A row of `entry`.
struct EntryRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "entry"

    var id: String
    /// `yyyy-MM-dd`, the same text `CalendarDate` renders, so SQL ordering matches date
    /// ordering without conversions.
    var occurredOn: String
    var payee: String?
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case occurredOn = "occurred_on"
        case payee
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(_ entry: Entry, timestamps: StoredTimestamps, updatedAt: Date) {
        self.id = entry.id.rawValue.uuidString
        self.occurredOn = entry.occurredOn.description
        self.payee = entry.payee
        self.note = entry.note
        self.createdAt = timestamps.createdAt ?? updatedAt
        self.updatedAt = updatedAt
        self.deletedAt = timestamps.deletedAt
    }
}

/// A row of `entry_line`.
struct EntryLineRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "entry_line"

    var id: String
    var entryID: String
    var accountID: String
    var amountMinor: Int64
    var currencyCode: String
    /// In the user's base currency, which lives in `app_setting` rather than in this row.
    var baseAmountMinor: Int64
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case entryID = "entry_id"
        case accountID = "account_id"
        case amountMinor = "amount_minor"
        case currencyCode = "currency_code"
        case baseAmountMinor = "base_amount_minor"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(_ line: EntryLine, entryID: EntryID, timestamps: StoredTimestamps, updatedAt: Date) {
        self.id = line.id.rawValue.uuidString
        self.entryID = entryID.rawValue.uuidString
        self.accountID = line.accountID.rawValue.uuidString
        self.amountMinor = line.amount.minorUnits
        self.currencyCode = line.amount.currency.value
        self.baseAmountMinor = line.baseAmount.minorUnits
        self.sortOrder = line.sortOrder
        self.createdAt = timestamps.createdAt ?? updatedAt
        self.updatedAt = updatedAt
        self.deletedAt = timestamps.deletedAt
    }

    func toDomain(baseCurrency: CurrencyCode) throws -> EntryLine {
        EntryLine(
            id: try EntryLineID(decoding: id, table: Self.databaseTableName),
            accountID: try AccountID(decoding: accountID, table: Self.databaseTableName),
            amount: Money(minorUnits: amountMinor, currency: try CurrencyCode(currencyCode)),
            baseAmount: Money(minorUnits: baseAmountMinor, currency: baseCurrency),
            sortOrder: sortOrder
        )
    }
}
