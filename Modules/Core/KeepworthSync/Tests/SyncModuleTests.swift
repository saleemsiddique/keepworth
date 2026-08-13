import Testing

@testable import KeepworthSync

@Test("The sync module links in the generated project")
func syncModuleLinks() {
    #expect(SyncModule.name == "KeepworthSync")
}
