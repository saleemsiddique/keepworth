import Foundation
import GRDB
import KeepworthDomain

/// A row of `institution`.
struct InstitutionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "institution"

    var id: String
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(_ institution: Institution, timestamps: StoredTimestamps, updatedAt: Date) {
        self.id = institution.id.rawValue.uuidString
        self.name = institution.name
        self.createdAt = timestamps.createdAt ?? updatedAt
        self.updatedAt = updatedAt
        self.deletedAt = timestamps.deletedAt
    }

    func toDomain() throws -> Institution {
        try Institution(
            id: try InstitutionID(decoding: id, table: Self.databaseTableName),
            name: name
        )
    }
}
