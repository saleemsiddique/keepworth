import Testing

@testable import KeepworthDesignSystem

@Test("El design system enlaza en el proyecto generado")
func designSystemModuleLinks() {
    #expect(DesignSystemModule.name == "KeepworthDesignSystem")
}
