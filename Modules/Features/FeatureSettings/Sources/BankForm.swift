import KeepworthDesignSystem
import KeepworthDomain
import Observation

/// The form behind adding a bank, and behind renaming one. A bank is a name and nothing else:
/// it groups accounts, holds no money and receives no movements.
///
/// No use case behind it, unlike accounts. There is no system bank to protect and no starting
/// balance to book, so `Institution.init` plus `save` is the whole operation — and a use case
/// that only forwarded would be a layer that explains nothing.
@MainActor
@Observable
public final class BankForm {
    public var name = ""
    public private(set) var lastFailure: BankFormFailure?

    /// The bank being renamed, or `nil` when adding one.
    private let editing: Institution?
    private let institutions: any InstitutionRepository

    public init(editing: Institution? = nil, institutions: any InstitutionRepository) {
        self.editing = editing
        self.institutions = institutions
        if let editing {
            self.name = editing.name
        }
    }

    public var availability: ActionAvailability {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .unavailable : .available
    }

    /// Saves, and says whether the screen should close.
    public func save() async -> Bool {
        do {
            // Keeping the id when renaming is what makes it a rename: a new one would leave
            // every account pointing at a bank that is no longer listed.
            let bank = try Institution(
                id: editing?.id ?? InstitutionID(),
                name: name,
                isArchived: editing?.isArchived ?? false
            )
            try await institutions.save(bank)
            return true
        } catch InstitutionError.blankName {
            lastFailure = .blankName
            return false
        } catch {
            lastFailure = .writeFailed
            return false
        }
    }

    public func dismissFailure() {
        lastFailure = nil
    }
}

public enum BankFormFailure: Hashable, Sendable {
    case blankName
    case writeFailed
}
