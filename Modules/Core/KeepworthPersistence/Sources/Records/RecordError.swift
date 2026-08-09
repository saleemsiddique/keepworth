import Foundation
import KeepworthDomain

/// A stored row that cannot become a domain entity.
///
/// The schema already rejects most of these on write, so reaching one means the row got in
/// some other way: a bug in a migration, a CSV import writing directly, or a sync conflict
/// with another version of the app. Failing loudly beats handing the app an entity the
/// domain believes cannot exist.
public enum RecordError: Error, Equatable {
    case malformedIdentifier(table: String, value: String)
    case unknownAccountKind(String)
    /// The ledger has movements but no base currency, so line amounts cannot be read.
    case missingBaseCurrency
}

extension Identifier {
    /// Reads an identifier stored as text.
    init(decoding text: String, table: String = "") throws {
        guard let uuid = UUID(uuidString: text) else {
            throw RecordError.malformedIdentifier(table: table, value: text)
        }
        self.init(uuid)
    }
}
