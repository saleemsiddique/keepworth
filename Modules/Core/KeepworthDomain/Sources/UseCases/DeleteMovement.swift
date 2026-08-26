/// Removes a movement, and puts it back if the user says so straight away.
///
/// Thin on purpose — there is no accounting rule to apply here, because a movement is deleted
/// whole or not at all. It exists so screens go through a use case like they do for everything
/// else, and so the day deleting *does* grow a rule there is one place to put it.
///
/// Deleting an **account** is a different matter and does have a rule —"no movements, delete;
/// movements, archive"— and it arrives with the screen that asks for it.
public struct DeleteMovement: Sendable {
    private let entries: any EntryRepository

    public init(entries: any EntryRepository) {
        self.entries = entries
    }

    public func execute(_ id: EntryID) async throws {
        try await entries.delete(id)
    }

    /// The other half of the undo a swipe offers. Separate from `execute` rather than a flag:
    /// they are two different things a screen asks for, not one with a switch.
    ///
    /// Takes the movement the screen removed, because that is what says which lines to bring
    /// back. It is already holding it — it was in the list a moment ago.
    public func undo(_ entry: Entry) async throws {
        try await entries.restore(entry)
    }
}
