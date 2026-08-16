import FeatureSupport
import Foundation
import KeepworthDesignSystem
import KeepworthDomain
import SwiftUI

/// Every movement, newest first, under the day it happened.
public struct TransactionsView: View {
    @State private var model: TransactionsModel
    private let formatter: MoneyFormatter
    private let dayFormat: Date.FormatStyle

    public init(
        model: TransactionsModel,
        formatter: MoneyFormatter,
        locale: Locale = .autoupdatingCurrent
    ) {
        self._model = State(initialValue: model)
        self.formatter = formatter
        self.dayFormat = CalendarDate.longDayStyle(in: locale)
    }

    public var body: some View {
        // A stable container, not a `Group` around the switch: a modifier on a `Group` applies
        // to each branch, so `task` would be cancelled and restarted on the first state change.
        ZStack {
            Color.bg.ignoresSafeArea()

            switch model.state {
            case .loading:
                EmptyView()
            case .ready(let days):
                ready(days)
            case .failed:
                failed
            }
        }
        .task { await model.observe() }
    }

    private func ready(_ days: [DayOfMovements]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.betweenSections) {
                if days.isEmpty {
                    EmptyStateLine(String(localized: "transactions.empty", bundle: .module))
                }

                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 0) {
                        SectionCaption(caption(for: day.day))

                        ForEach(day.movements) { movement in
                            MovementRow(
                                entry: movement,
                                accountNames: model.accountNames,
                                moneyAccountIDs: model.moneyAccountIDs,
                                formatter: formatter
                            )
                            if movement.id != day.movements.last?.id {
                                Hairline()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.screenMargin)
        }
    }

    private var failed: some View {
        VStack(spacing: Spacing.row) {
            Text("transactions.failed", bundle: .module)
                .font(.rowTitle)
                .foregroundStyle(.ink)
                .multilineTextAlignment(.center)
            // `observe`, not `load`: the stream ends when it fails, so retrying with a plain
            // reload would repaint the figures and leave the screen without a subscription
            // for good — the silent staleness this whole mechanism exists to prevent.
            PrimaryAction(String(localized: "transactions.retry", bundle: .module)) {
                Task { await model.observe() }
            }
        }
        .padding(Spacing.screenMargin)
    }

    private func caption(for day: CalendarDate) -> String {
        day.formatted(dayFormat)
    }
}
