import Foundation

/// A typed entity identifier.
///
/// The generic parameter is never stored: it exists so the compiler rejects passing an
/// account id where an entry id is expected.
///
/// UUIDs, never autoincrementing: two offline devices both creating row 7 would break
/// CloudKit sync beyond repair.
public struct Identifier<Subject>: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue.uuidString }
}

public typealias InstitutionID = Identifier<Institution>
public typealias AccountID = Identifier<Account>
public typealias EntryID = Identifier<Entry>
public typealias EntryLineID = Identifier<EntryLine>
