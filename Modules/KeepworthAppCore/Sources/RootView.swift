import SwiftUI

/// The app's root view.
///
/// The real navigation and the dependency container that injects concrete repositories
/// into each feature arrive in Phase 4.
public struct RootView: View {
    public init() {}

    public var body: some View {
        // `verbatim` on purpose: localisable text lives in the String Catalog, which
        // arrives with the first real screens.
        Text(verbatim: "Keepworth")
    }
}
