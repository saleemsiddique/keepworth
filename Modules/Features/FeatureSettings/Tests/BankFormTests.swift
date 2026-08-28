import KeepworthDomain
import Testing

@testable import FeatureSettings

@MainActor
@Test("A bank cannot be saved without a name")
func bankNameIsRequired() async throws {
    let form = BankForm(institutions: FakeInstitutionRepository())

    #expect(form.availability == .unavailable)
    form.name = "BBVA"
    #expect(form.availability == .available)
}

@MainActor
@Test("Adding a bank puts it on the list")
func addingABank() async throws {
    let institutions = FakeInstitutionRepository()
    let form = BankForm(institutions: institutions)
    form.name = "Trade Republic"

    #expect(await form.save())

    #expect(try await institutions.allInstitutions().map(\.name) == ["Trade Republic"])
}

/// The one that would go unnoticed: a rename that saved under a new id would leave every
/// account pointing at a bank no longer on the list.
@MainActor
@Test("Renaming a bank keeps its id, so its accounts keep pointing at it")
func renamingKeepsTheID() async throws {
    let bbva = try Institution(name: "BBVA")
    let institutions = FakeInstitutionRepository([bbva])
    let form = BankForm(editing: bbva, institutions: institutions)
    form.name = "BBVA España"

    #expect(await form.save())

    let stored = try await institutions.allInstitutions()
    #expect(stored.count == 1)
    #expect(stored.first?.id == bbva.id)
    #expect(stored.first?.name == "BBVA España")
}

@MainActor
@Test("Renaming an archived bank leaves it archived")
func renamingKeepsItArchived() async throws {
    let retired = try Institution(name: "Bankia", isArchived: true)
    let institutions = FakeInstitutionRepository([retired])
    let form = BankForm(editing: retired, institutions: institutions)
    form.name = "Bankia (cerrado)"

    #expect(await form.save())

    #expect(try await institutions.allInstitutions().first?.isArchived == true)
}
