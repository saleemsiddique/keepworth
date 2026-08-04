import Testing

@testable import KeepworthAppCore

// En modo de lenguaje Swift 6, conformar a `View` aísla el inicializador al actor
// principal: cualquier test que construya una vista tiene que declararse igual.
@MainActor
@Test("La vista raíz se construye")
func rootViewInitialises() {
    _ = RootView()
}
