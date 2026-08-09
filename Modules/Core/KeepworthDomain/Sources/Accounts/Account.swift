/// A place money moves into or out of.
///
/// Accounts and categories share a type on purpose; only `kind` tells them apart. The UI
/// never mixes them in the same list.
public struct Account: Hashable, Sendable, Identifiable {
    public let id: AccountID
    /// `nil` for cash and for every category.
    public let institutionID: InstitutionID?
    public let name: String
    public let kind: AccountKind
    public let currency: CurrencyCode
    /// SF Symbol name.
    public let symbolName: String?
    /// True only for "Opening balance": never deleted, never renamed.
    public let isSystem: Bool
    /// Archived accounts leave the editor but stay in history. This is what happens instead
    /// of deleting once an account has movements, which would orphan them.
    public let isArchived: Bool

    public init(
        id: AccountID = AccountID(),
        institutionID: InstitutionID? = nil,
        name: String,
        kind: AccountKind,
        currency: CurrencyCode,
        symbolName: String? = nil,
        isSystem: Bool = false,
        isArchived: Bool = false
    ) throws {
        let trimmedName = name.trimmedForStorage
        guard !trimmedName.isEmpty else {
            throw AccountError.blankName
        }
        if institutionID != nil && !kind.canBelongToInstitution {
            throw AccountError.kindCannotBelongToInstitution(kind)
        }
        self.id = id
        self.institutionID = institutionID
        self.name = trimmedName
        self.kind = kind
        self.currency = currency
        self.symbolName = symbolName?.trimmedForStorageOrNil
        self.isSystem = isSystem
        self.isArchived = isArchived
    }

    public var countsTowardsNetWorth: Bool { kind.countsTowardsNetWorth }
}

public enum AccountError: Error, Equatable {
    case blankName
    /// A category or the opening balance account was put inside a bank. A bank groups
    /// places holding money, and a category is not one.
    case kindCannotBelongToInstitution(AccountKind)
}
