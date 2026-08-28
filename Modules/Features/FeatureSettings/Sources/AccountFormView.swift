import KeepworthDesignSystem
import KeepworthDomain
import SwiftUI

/// Opening an account, and correcting one.
///
/// The starting balance is asked for only when the account is new, and its keypad is the
/// same one the movement editor uses. Its sign is not a switch the user has to find: what a
/// card already held is money owed, and what an account already held is money there.
struct AccountFormView: View {
    @State var form: AccountForm
    let banks: [Institution]
    let formatter: MoneyFormatter

    @Environment(\.dismiss) private var dismiss
    @State private var isChoosingBank = false

    /// Belonging to no bank is a real answer — cash does — so it is a case of its own rather
    /// than a `nil` compared against an optional of an optional.
    private enum BankChoice: Hashable {
        case none
        case bank(InstitutionID)
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.betweenSections) {
                    if form.canChooseKind {
                        kind
                    }
                    fields
                    if form.asksForStartingBalance {
                        startingBalance
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.screenMargin)
            }
        }
        .navigationTitle(Text("settings.account", bundle: .module))
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
        .navigationDestination(isPresented: $isChoosingBank) { bankPicker }
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

    private var kind: some View {
        ChoiceBar(
            selection: $form.kind,
            items: [
                ChoiceItem(
                    tag: AccountKind.asset,
                    title: String(localized: "settings.kind.asset", bundle: .module)
                ),
                ChoiceItem(
                    tag: AccountKind.liability,
                    title: String(localized: "settings.kind.liability", bundle: .module)
                ),
            ]
        )
    }

    private var fields: some View {
        VStack(spacing: 0) {
            TextEntryRow(
                title: String(localized: "settings.name", bundle: .module),
                prompt: String(localized: "settings.namePrompt", bundle: .module),
                text: $form.name
            )
            Hairline()
            FormRow(
                title: String(localized: "settings.bank", bundle: .module),
                value: chosenBankName
            ) {
                isChoosingBank = true
            }
        }
    }

    private var startingBalance: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            SectionCaption(String(localized: "settings.startingBalance", bundle: .module))

            HeadlineAmount(
                caption: String(localized: "settings.alreadyHeld", bundle: .module),
                amount: formatter.string(for: form.typedStartingBalance)
            )

            AmountKeypad(
                onDigit: { form.startingBalance.append($0) },
                onDelete: { form.startingBalance.deleteLast() }
            )
        }
    }

    private var chosenBankName: String {
        guard let bankID = form.bankID else {
            return String(localized: "settings.noBank", bundle: .module)
        }
        return banks.first { $0.id == bankID }?.name
            ?? String(localized: "settings.noBank", bundle: .module)
    }

    private var chosenBank: BankChoice {
        form.bankID.map(BankChoice.bank) ?? .none
    }

    private var bankPicker: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SelectionRow(
                        tag: BankChoice.none,
                        selection: chosenBank,
                        title: String(localized: "settings.noBank", bundle: .module)
                    ) {
                        form.bankID = nil
                        isChoosingBank = false
                    }
                    Hairline()

                    ForEach(banks) { bank in
                        SelectionRow(
                            tag: BankChoice.bank(bank.id),
                            selection: chosenBank,
                            title: bank.name
                        ) {
                            form.bankID = bank.id
                            isChoosingBank = false
                        }
                        if bank.id != banks.last?.id {
                            Hairline()
                        }
                    }
                }
                .padding(Spacing.screenMargin)
            }
        }
        .navigationTitle(Text("settings.bank", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
    }
}
