import Testing

@testable import KeepworthPersistence

@Test("El módulo de persistencia enlaza en el proyecto generado")
func persistenceModuleLinks() {
    #expect(PersistenceModule.name == "KeepworthPersistence")
}
