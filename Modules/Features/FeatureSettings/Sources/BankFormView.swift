import KeepworthDesignSystem
import SwiftUI

/// Adding a bank, and renaming one. A bank is a name: it groups accounts, holds no money and
/// receives no movements, so there is nothing else to ask for.
struct BankFormView: View {
    @State var form: BankForm

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                TextEntryRow(
                    title: String(localized: "settings.name", bundle: .module),
                    prompt: String(localized: "settings.bankNamePrompt", bundle: .module),
                    text: $form.name
                )
                Hairline()
            }
            .padding(Spacing.screenMargin)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle(Text("settings.bank", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                PrimaryAction(
                    String(localized: "settings.save", bundle: .module),
                    availability: form.availability
                ) {
                    Task {
                        if await form.save() { dismiss() }
                    }
                }
            }
        }
        .alert(
            Text("settings.saveFailed", bundle: .module),
            isPresented: failureIsShowing
        ) {
            Button(String(localized: "settings.ok", bundle: .module)) {
                form.dismissFailure()
            }
        }
    }

    private var failureIsShowing: Binding<Bool> {
        Binding(
            get: { form.lastFailure != nil },
            set: { isShowing in
                if !isShowing { form.dismissFailure() }
            }
        )
    }
}
