import Foundation
import GRDB
import KeepworthDomain

/// A row of `account`.
///
/// Kept separate from `Account` because the domain cannot import GRDB — and that separation
/// is what forces every read through `Account.init`, the initialiser that rejects a category
/// inside a bank. Decoding straight into the entity would let a bad row become an object the
/// domain believes impossible.
struct AccountRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "account"

    var id: String
    var institutionID: String?
    var name: String
    var kind: String
    var currencyCode: String
    var symbolName: String?
    var isSystem: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case institutionID = "institution_id"
        case name
        case kind
        case currencyCode = "currency_code"
        case symbolName = "symbol_name"
        case isSystem = "is_system"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(_ account: Account, timestamps: StoredTimestamps, updatedAt: Date) {
        self.id = account.id.rawValue.uuidString
        self.institutionID = account.institutionID?.rawValue.uuidString
        self.name = account.name
        self.kind = account.kind.rawValue
        self.currencyCode = account.currency.value
        self.symbolName = account.symbolName
        self.isSystem = account.isSystem
        self.isArchived = account.isArchived
        self.createdAt = timestamps.createdAt ?? updatedAt
        self.updatedAt = updatedAt
        self.deletedAt = timestamps.deletedAt
    }

    func toDomain() throws -> Account {
        guard let uuid = UUID(uuidString: id) else {
            throw RecordError.malformedIdentifier(table: Self.databaseTableName, value: id)
        }
        guard let kind = AccountKind(rawValue: kind) else {
            throw RecordError.unknownAccountKind(kind)
        }
        return try Account(
            id: AccountID(uuid),
            institutionID: try institutionID.map { try InstitutionID(decoding: $0) },
            name: name,
            kind: kind,
            currency: try CurrencyCode(currencyCode),
            symbolName: symbolName,
            isSystem: isSystem,
            isArchived: isArchived
        )
    }
}
