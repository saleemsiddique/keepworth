/// A bank: BBVA, Trade Republic, MyInvestor.
///
/// Groups accounts and gives a total per institution. Holds no money and receives no
/// movements, which is why it is not an `Account`.
public struct Institution: Hashable, Sendable, Identifiable {
    public let id: InstitutionID
    public let name: String
    /// A bank the user no longer deals with. It leaves the pickers but keeps grouping the
    /// accounts it already holds, which are still theirs and still count.
    public let isArchived: Bool

    public init(
        id: InstitutionID = InstitutionID(),
        name: String,
        isArchived: Bool = false
    ) throws {
        let trimmedName = name.trimmedForStorage
        guard !trimmedName.isEmpty else {
            throw InstitutionError.blankName
        }
        self.id = id
        self.name = trimmedName
        self.isArchived = isArchived
    }
}

public enum InstitutionError: Error, Equatable {
    case blankName
}
