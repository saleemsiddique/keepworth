import KeepworthDesignSystem
import KeepworthDomain
import SwiftUI

/// Where accounts and banks are opened, corrected and put away.
///
/// A sheet with its own navigation stack rather than a destination pushed from the summary:
/// configuring the app is not a detail of the money, and the summary's stack stays the one
/// place the period report lives.
///
/// Accounts are listed flat with their bank on the right, not nested under it. Settings
/// answers "what accounts do I have", and the summary is where the grouping earns its keep
/// because that is where the totals per bank are.
public struct SettingsView: View {
    @State private var model: SettingsModel
    @State private var route: Route?
    private let dependencies: SettingsDependencies

    public init(model: SettingsModel, dependencies: SettingsDependencies) {
        self._model = State(initialValue: model)
        self.dependencies = dependencies
    }

    /// What a tap opens. One value rather than a flag per destination, so two of them cannot
    /// be open at once.
    private enum Route: Hashable {
        case newAccount
        case account(Account)
        case newBank
        case bank(Institution)
    }

    public var body: some View {
        NavigationStack {
            // A stable container, not a `Group` around the switch: a modifier on a `Group` is
            // applied to each branch, so `task` would be cancelled and restarted on the first
            // state change.
            ZStack {
                Color.surface.ignoresSafeArea()

                switch model.state {
                case .loading:
                    EmptyView()
                case .ready(let snapshot):
                    ready(snapshot)
                case .failed:
                    failed
                }
            }
            .navigationTitle(Text("settings.title", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $route) { destination($0) }
        }
        .task { await model.observe() }
        .alert(
            Text("settings.actionFailed", bundle: .module),
            isPresented: failureIsShowing
        ) {
            Button(String(localized: "settings.ok", bundle: .module)) {
                model.dismissFailure()
            }
        } message: {
            if model.lastFailure == .systemAccount {
                Text("settings.systemAccount", bundle: .module)
            }
        }
    }

    private var failureIsShowing: Binding<Bool> {
        Binding(
            get: { model.lastFailure != nil },
            set: { isShowing in
                if !isShowing { model.dismissFailure() }
            }
        )
    }

    private func ready(_ snapshot: SettingsSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.betweenSections) {
                accounts(snapshot)
                banks(snapshot)
                archived(snapshot)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.screenMargin)
        }
        .safeAreaInset(edge: .bottom) {
            // Two actions of equal weight, one at each edge. They are the two things this
            // screen is for and neither leads to the other, so giving one the bottom bar and
            // burying the other in a row made them look like different kinds of thing.
            HStack(spacing: Spacing.row) {
                PrimaryAction(String(localized: "settings.newAccount", bundle: .module)) {
                    route = .newAccount
                }

                Spacer(minLength: Spacing.row)

                PrimaryAction(String(localized: "settings.newBank", bundle: .module)) {
                    route = .newBank
                }
            }
            .padding(Spacing.screenMargin)
            .frame(maxWidth: .infinity)
            .background(.surface)
        }
    }

    private func accounts(_ snapshot: SettingsSnapshot) -> some View {
        let live = snapshot.banks.flatMap(\.accounts) + snapshot.unbanked

        return VStack(alignment: .leading, spacing: 0) {
            SectionCaption(String(localized: "settings.accounts", bundle: .module))

            if live.isEmpty {
                EmptyStateLine(String(localized: "settings.noAccounts", bundle: .module))
            }

            ForEach(live) { account in
                FormRow(title: account.name, value: bankName(of: account, in: snapshot)) {
                    route = .account(account)
                }
                .contextMenu {
                    Button(String(localized: "settings.archive", bundle: .module)) {
                        Task { await model.archive(account) }
                    }
                }
                if account.id != live.last?.id {
                    Hairline()
                }
            }
        }
    }

    private func banks(_ snapshot: SettingsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption(String(localized: "settings.banks", bundle: .module))

            if snapshot.banks.isEmpty {
                EmptyStateLine(String(localized: "settings.noBanks", bundle: .module))
            }

            ForEach(snapshot.banks) { banked in
                FormRow(title: banked.bank.name) { route = .bank(banked.bank) }
                    .contextMenu {
                        Button(String(localized: "settings.archive", bundle: .module)) {
                            Task { await model.archive(banked.bank) }
                        }
                    }
                if banked.id != snapshot.banks.last?.id {
                    Hairline()
                }
            }
        }
    }

    /// Only drawn when there is something in it. An empty "Archived" heading would suggest a
    /// place things go, on a screen where nothing has gone there yet.
    @ViewBuilder
    private func archived(_ snapshot: SettingsSnapshot) -> some View {
        if !snapshot.archived.isEmpty || !snapshot.archivedBanks.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionCaption(String(localized: "settings.archived", bundle: .module))

                ForEach(snapshot.archived) { account in
                    LedgerRow(title: account.name, symbolName: account.symbolName, amount: "")
                        .contextMenu {
                            Button(String(localized: "settings.unarchive", bundle: .module)) {
                                Task { await model.unarchive(account) }
                            }
                        }
                    Hairline()
                }

                ForEach(snapshot.archivedBanks) { bank in
                    LedgerRow(title: bank.name, amount: "")
                        .contextMenu {
                            Button(String(localized: "settings.unarchive", bundle: .module)) {
                                Task { await model.unarchive(bank) }
                            }
                        }
                    Hairline()
                }
            }
        }
    }

    private func bankName(of account: Account, in snapshot: SettingsSnapshot) -> String {
        guard let bankID = account.institutionID else { return "" }
        return snapshot.banks.first { $0.bank.id == bankID }?.bank.name ?? ""
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .newAccount:
            AccountFormView(
                form: dependencies.accountForm(editing: nil, currency: currentCurrency),
                banks: currentBanks,
                formatter: dependencies.formatter
            )
        case .account(let account):
            AccountFormView(
                form: dependencies.accountForm(editing: account, currency: currentCurrency),
                banks: currentBanks,
                formatter: dependencies.formatter
            )
        case .newBank:
            BankFormView(form: dependencies.bankForm(editing: nil))
        case .bank(let bank):
            BankFormView(form: dependencies.bankForm(editing: bank))
        }
    }

    private var currentBanks: [Institution] {
        guard case .ready(let snapshot) = model.state else { return [] }
        return snapshot.banks.map(\.bank)
    }

    /// The euro only stands in while the list is still loading, and no form can be opened
    /// before it has: a route is only reachable from a row that the snapshot drew.
    private var currentCurrency: CurrencyCode {
        guard case .ready(let snapshot) = model.state else { return .eur }
        return snapshot.baseCurrency
    }

    private var failed: some View {
        VStack(spacing: Spacing.row) {
            Text("settings.failed", bundle: .module)
                .font(.rowTitle)
                .foregroundStyle(.ink)
                .multilineTextAlignment(.center)
            // `observe`, not `load`: the stream ends when it fails, so retrying with a plain
            // reload would repaint the list and leave the screen without a subscription.
            PrimaryAction(String(localized: "settings.retry", bundle: .module)) {
                Task { await model.observe() }
            }
        }
        .padding(Spacing.screenMargin)
    }
}
