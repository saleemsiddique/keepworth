import KeepworthDesignSystem
import KeepworthDomain
import SwiftUI

/// Net worth, the accounts behind it, what the month did, and the last few movements.
public struct SummaryView: View {
    @State private var model: SummaryModel
    private let formatter: MoneyFormatter
    @State private var showsReport = false

    public init(model: SummaryModel, formatter: MoneyFormatter) {
        self._model = State(initialValue: model)
        self.formatter = formatter
    }

    public var body: some View {
        // A stable container, not a `Group` around the switch: a modifier on a `Group` is
        // applied to each branch, so `task` would be cancelled and restarted every time the
        // state changed — and the first change is the one that arrives on load.
        ZStack {
            Color.bg.ignoresSafeArea()

            switch model.state {
            case .loading:
                EmptyView()
            case .ready(let snapshot):
                ready(snapshot)
            case .failed:
                failed
            }
        }
        .task { await model.observe() }
    }

    private func ready(_ snapshot: SummarySnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.betweenSections) {
                HeadlineAmount(
                    caption: String(localized: "summary.netWorth", bundle: .module),
                    amount: formatter.string(for: snapshot.netWorth),
                    detail: formatter.signedString(for: snapshot.monthChange)
                )

                accounts(snapshot)
                thisMonth(snapshot)
                recent(snapshot)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.screenMargin)
        }
        .navigationDestination(isPresented: $showsReport) {
            PeriodReportView(
                summary: snapshot.month,
                accountNames: snapshot.accountNames,
                formatter: formatter
            )
        }
    }

    private func accounts(_ snapshot: SummarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption(String(localized: "summary.accounts", bundle: .module))

            if snapshot.institutions.isEmpty && snapshot.unbanked.isEmpty {
                EmptyStateLine(String(localized: "summary.noAccounts", bundle: .module))
            }

            ForEach(snapshot.institutions) { bank in
                LedgerRow(
                    title: bank.institution.name,
                    amount: formatter.string(for: bank.total)
                )
                Hairline()
                // Indented here rather than by `LedgerRow`: this and the design system gallery
                // are the only places that nest rows so far.
                ForEach(bank.accounts) { held in
                    row(for: held).padding(.leading, Spacing.screenMargin)
                    Hairline()
                }
            }

            ForEach(snapshot.unbanked) { loose in
                row(for: loose)
                if loose.id != snapshot.unbanked.last?.id {
                    Hairline()
                }
            }
        }
    }

    /// A balance is a state, so it carries no sign and no colour — unless it is negative, and
    /// then the minus says there is debt and `expense` makes it hard to miss among positives.
    private func row(for held: AccountBalance) -> some View {
        LedgerRow(
            title: held.account.name,
            symbolName: held.account.symbolName,
            amount: formatter.string(for: held.balance),
            direction: held.balance.isNegative ? .outgoing : .neutral
        )
    }

    private func thisMonth(_ snapshot: SummarySnapshot) -> some View {
        Button {
            showsReport = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                SectionCaption(String(localized: "summary.thisMonth", bundle: .module))
                LedgerRow(
                    title: String(localized: "summary.spent", bundle: .module),
                    amount: formatter.signedString(for: negated(snapshot.month.totalExpenses)),
                    direction: .outgoing
                )
                Hairline()
                // `ink`, not the accent: what was saved is a derived figure, not money that
                // came in from anywhere.
                LedgerRow(
                    title: String(localized: "summary.saved", bundle: .module),
                    amount: formatter.signedString(for: snapshot.month.saved)
                )
            }
        }
        .buttonStyle(.plain)
    }

    private func recent(_ snapshot: SummarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaption(String(localized: "summary.recent", bundle: .module))

            if snapshot.recent.isEmpty {
                EmptyStateLine(String(localized: "summary.noMovements", bundle: .module))
            }

            ForEach(snapshot.recent) { entry in
                MovementRow(
                    entry: entry,
                    accountNames: snapshot.accountNames,
                    moneyAccountIDs: snapshot.moneyAccountIDs,
                    formatter: formatter
                )
                if entry.id != snapshot.recent.last?.id {
                    Hairline()
                }
            }
        }
    }

    private var failed: some View {
        VStack(spacing: Spacing.row) {
            Text("summary.failed", bundle: .module)
                .font(.rowTitle)
                .foregroundStyle(.ink)
                .multilineTextAlignment(.center)
            PrimaryAction(String(localized: "summary.retry", bundle: .module)) {
                Task { await model.load() }
            }
        }
        .padding(Spacing.screenMargin)
    }

    /// Spending is stored as a positive total, and the screen shows it as money leaving.
    private func negated(_ amount: Money) -> Money {
        (try? amount.negated()) ?? amount
    }
}
