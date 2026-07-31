import Testing

@testable import KeepworthDomain

@Test("El módulo de dominio enlaza en el proyecto generado")
func domainModuleLinks() {
    #expect(DomainModule.name == "KeepworthDomain")
}
