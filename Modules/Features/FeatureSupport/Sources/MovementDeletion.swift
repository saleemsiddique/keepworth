import Foundation
import KeepworthDomain
import Observation

/// Deleting a movement, and the few seconds afterwards in which it can be taken back.
///
/// Shared by both screens that list movements. The undo is not a nicety: a swipe removes a
/// figure from someone's accounts in one gesture, and an accidental one goes unnoticed until
/// the totals stop making sense — by which point the user cannot know which movement is
/// missing.
@MainActor
@Observable
public final class MovementDeletion {
    /// The movement just removed, while the offer to undo still stands. `nil` the rest of the
    /// time, which is what the banner keys off.
    public private(set) var undoable: Entry?
    public private(set) var failed = false

    private let deletion: DeleteMovement
    private let window: Duration
    private var expiry: Task<Void, Never>?

    public init(entries: any EntryRepository, window: Duration = .seconds(5)) {
        self.deletion = DeleteMovement(entries: entries)
        self.window = window
    }

    public func delete(_ entry: Entry) async {
        do {
            try await deletion.execute(entry.id)
            offerUndo(of: entry)
        } catch {
            failed = true
        }
    }

    public func undo() async {
        guard let entry = undoable else { return }
        withdrawOffer()
        do {
            try await deletion.undo(entry)
        } catch {
            failed = true
        }
    }

    public func dismissFailure() {
        failed = false
    }

    private func offerUndo(of entry: Entry) {
        expiry?.cancel()
        undoable = entry
        expiry = Task { [window] in
            try? await Task.sleep(for: window)
            guard !Task.isCancelled else { return }
            undoable = nil
        }
    }

    private func withdrawOffer() {
        expiry?.cancel()
        expiry = nil
        undoable = nil
    }
}
