import Foundation
import GRDB
import KeepworthDomain

/// Watches the database and says when it moved.
///
/// The whole database, not a list of tables. The signal carries no detail, so narrowing the
/// region would buy nothing and would add one way to be wrong: forgetting a table means a
/// screen that silently stops updating.
///
/// **One observation for the whole app, fanned out to every listener.** Not one per call:
/// `DatabaseRegionObservation.start` blocks the calling thread until it can take write access,
/// so a screen calling `changes()` on the main actor while an import is running would freeze
/// the app. Starting once, at launch, is the difference between paying that wait never and
/// paying it on every screen.
public final class SQLiteLedgerChanges: LedgerChanges, @unchecked Sendable {
    private let lock = NSLock()
    private var listeners: [UUID: AsyncThrowingStream<Void, any Error>.Continuation] = [:]
    private var observation: AnyDatabaseCancellable?

    /// Starts observing. Build it once, in the composition root, and **off the main actor**:
    /// this is the call that can block waiting for the writer.
    public init(database: AppDatabase) {
        observation = DatabaseRegionObservation(tracking: DatabaseRegion.fullDatabase)
            .start(
                in: database.writer,
                onError: { [weak self] error in self?.finishAll(throwing: error) },
                // The `Database` handle is deliberately dropped: reading it here would run on
                // the writer's queue and turn a notification into a query.
                onChange: { [weak self] _ in self?.notifyAll() }
            )
    }

    deinit {
        observation?.cancel()
    }

    public func changes() -> AsyncThrowingStream<Void, any Error> {
        // One slot, not the unbounded default. Two signals mean the same as one — the ledger
        // moved — so an import of twenty movements should cost one reload on return, not
        // twenty.
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.withLock { listeners[id] = continuation }
            // Strong `self`, on purpose: the stream has to keep the observation alive. A weak
            // capture makes `changes()` on a value nobody else holds return a stream that
            // never fires, because `deinit` cancels on the way out — silent, and exactly the
            // shape of a bug nobody finds. The retain ends when the last listener does: the
            // continuation is dropped, the cycle breaks, and `deinit` cancels for real.
            continuation.onTermination = { [self] _ in
                lock.withLock { _ = listeners.removeValue(forKey: id) }
            }
        }
    }

    private func notifyAll() {
        for listener in currentListeners() {
            listener.yield()
        }
    }

    private func finishAll(throwing error: any Error) {
        for listener in currentListeners() {
            listener.finish(throwing: error)
        }
    }

    /// Copied out of the lock before use. `NSLock` is not reentrant, and a listener released
    /// while the array is walked runs its `onTermination`, which takes this same lock.
    private func currentListeners() -> [AsyncThrowingStream<Void, any Error>.Continuation] {
        lock.withLock { Array(listeners.values) }
    }
}
