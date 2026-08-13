import Testing

@testable import KeepworthDesignSystem

@Test("The design system links in the generated project")
func designSystemModuleLinks() {
    #expect(DesignSystemModule.name == "KeepworthDesignSystem")
}
