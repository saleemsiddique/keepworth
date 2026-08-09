import Foundation

/// Identificador tipado de una entidad.
///
/// El parámetro genérico no se almacena: existe para que el compilador impida pasar el
/// identificador de una cuenta donde se espera el de un asiento, que es un fallo que sin
/// tipos no aparece hasta que los datos ya están mal.
///
/// Son UUID y **nunca autoincrementales**: dos dispositivos sin conexión que crearan la
/// fila número 7 a la vez romperían el sync con CloudKit de forma irreparable.
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
