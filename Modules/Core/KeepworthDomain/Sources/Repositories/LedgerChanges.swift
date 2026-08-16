/// Says the ledger changed. It does not say what changed, and that is the design.
///
/// A screen already knows how to load what it shows; what it cannot know is *when* to do it
/// again. Telling it only that something moved keeps that knowledge in one place instead of
/// asking every write path to remember who is watching — and a forgotten notification in a
/// finance app shows up as a figure that is quietly wrong.
///
/// Coarse on purpose. A signal per query would refresh less, but every query would need its
/// own observed variant and its own faithful double, and the failure it prevents is one
/// nobody would notice: recomputing a screen's worth of small SQLite reads.
public protocol LedgerChanges: Sendable {
    /// A fresh sequence per call, because several screens listen at once and each needs its
    /// own. It does not finish on its own: it ends when the listener stops, or throws if
    /// watching became impossible.
    ///
    /// Throwing rather than finishing quietly. A sequence that just ends leaves a screen
    /// showing figures that will never update again, with nothing on screen to say so.
    func changes() -> AsyncThrowingStream<Void, any Error>
}
