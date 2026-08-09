/// Acceso a los bancos.
///
/// Se declara aquí y se implementa en `KeepworthPersistence`. Las features hablan con este
/// protocolo, nunca con GRDB, y por eso se pueden testear con dobles en memoria.
public protocol InstitutionRepository: Sendable {
    /// Falla si no existe, en vez de devolver `nil`: un banco que no está es un error del
    /// que llama, no un caso normal que cada llamador tenga que defender.
    func institution(withID id: InstitutionID) async throws -> Institution
    func allInstitutions() async throws -> [Institution]
}

/// Acceso a las cuentas y a las categorías, que son la misma tabla.
public protocol AccountRepository: Sendable {
    func account(withID id: AccountID) async throws -> Account
    func accounts(ofKinds kinds: Set<AccountKind>) async throws -> [Account]
    func accounts(inInstitution id: InstitutionID) async throws -> [Account]
}

/// Acceso a los movimientos.
public protocol EntryRepository: Sendable {
    func save(_ entry: Entry) async throws
    /// Devuelve las líneas **vivas** que cumplen la consulta: ni la línea ni su asiento
    /// pueden estar borrados. Filtrar solo por la línea deja vivas las de asientos borrados
    /// y descuadra los saldos sin dar ningún síntoma.
    func lines(matching query: EntryLineQuery) async throws -> [EntryLine]
}

/// Qué líneas se quieren leer.
///
/// Un solo tipo de consulta en vez de un método por combinación: el patrimonio pide las de
/// unas cuentas hasta una fecha, y el informe las de un rango, pero es la misma pregunta.
public struct EntryLineQuery: Hashable, Sendable {
    /// Cuentas cuyas líneas interesan. Siempre explícitas: no hay «todas», porque ninguna
    /// pregunta del dominio lo necesita y una consulta sin filtro de cuenta sobre un
    /// historial largo es justo la que no queremos que nadie escriba por descuido.
    public let accountIDs: Set<AccountID>
    /// Primer día incluido. `nil` significa desde el principio.
    public let from: CalendarDate?
    /// Último día incluido. `nil` significa hasta el final, **incluido el futuro**.
    public let through: CalendarDate?

    public init(
        accountIDs: Set<AccountID>,
        from: CalendarDate? = nil,
        through: CalendarDate? = nil
    ) {
        self.accountIDs = accountIDs
        self.from = from
        self.through = through
    }
}

public enum RepositoryError: Error, Equatable {
    case accountNotFound(AccountID)
    case institutionNotFound(InstitutionID)
}
