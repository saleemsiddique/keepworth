import Testing

@testable import KeepworthAppCore

@Test("La vista raíz se construye")
func rootViewInitialises() {
    _ = RootView()
}
