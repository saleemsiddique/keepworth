import Testing

@testable import KeepworthAppCore

// Under the Swift 6 language mode, conforming to `View` isolates the initialiser to the
// main actor, so any test building a view must be isolated too.
@MainActor
@Test("The root view builds")
func rootViewInitialises() {
    _ = RootView()
}
