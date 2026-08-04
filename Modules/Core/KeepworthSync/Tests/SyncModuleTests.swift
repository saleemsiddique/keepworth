import Testing

@testable import KeepworthSync

@Test("El módulo de sincronización enlaza en el proyecto generado")
func syncModuleLinks() {
    #expect(SyncModule.name == "KeepworthSync")
}
