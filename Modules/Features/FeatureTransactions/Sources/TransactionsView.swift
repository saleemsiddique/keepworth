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
        self.dayFormat = Date.FormatStyle.dateTime
            .day().month(.wide).year()
            .locale(locale)
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
            PrimaryAction(String(localized: "transactions.retry", bundle: .module)) {
                Task { await model.load() }
            }
        }
        .padding(Spacing.screenMargin)
    }

    /// A `CalendarDate` has no time zone, so it is turned into text at noon UTC: any other
    /// hour could land on the day before or after depending on where it is read, which is the
    /// bug the type exists to prevent.
    private func caption(for day: CalendarDate) -> String {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = 12
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let instant = calendar.date(from: components) else { return day.description }
        return instant.formatted(dayFormat)
    }
}
