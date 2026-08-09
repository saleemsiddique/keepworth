/// A bank: BBVA, Trade Republic, MyInvestor.
///
/// Groups accounts and gives a total per institution. Holds no money and receives no
/// movements, which is why it is not an `Account`.
public struct Institution: Hashable, Sendable, Identifiable {
    public let id: InstitutionID
    public let name: String

    public init(id: InstitutionID = InstitutionID(), name: String) throws {
        let trimmedName = name.trimmedForStorage
        guard !trimmedName.isEmpty else {
            throw InstitutionError.blankName
        }
        self.id = id
        self.name = trimmedName
    }
}

public enum InstitutionError: Error, Equatable {
    case blankName
}
