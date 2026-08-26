import FeatureSupport
import Foundation
import KeepworthDesignSystem
import KeepworthDomain
import SwiftUI

/// Every movement, newest first, under the day it happened.
public struct TransactionsView: View {
    @State private var model: TransactionsModel
    @State private var deletion: MovementDeletion
    private let formatter: MoneyFormatter
    private let dayFormat: Date.FormatStyle

    public init(
        model: TransactionsModel,
        deletion: MovementDeletion,
        formatter: MoneyFormatter,
        locale: Locale = .autoupdatingCurrent
    ) {
        self._model = State(initialValue: model)
        self._deletion = State(initialValue: deletion)
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

            if let undoable = deletion.undoable {
                VStack {
                    Spacer()
                    UndoBanner(
                        message: String(localized: "transactions.deleted", bundle: .module),
                        undoTitle: String(localized: "transactions.undo", bundle: .module)
                    ) {
                        Task { await deletion.undo() }
                    }
                }
                .id(undoable.id)
            }
        }
        .animation(.default, value: deletion.undoable?.id)
        .task { await model.observe() }
    }

    /// A `List` and not a `ScrollView`, unlike every other screen. Two reasons, and neither is
    /// taste: swipe to delete is a `List` affordance, and this is the one screen whose length
    /// grows without bound, where building every row up front stops being free.
    ///
    /// Its chrome is turned off row by row so it looks like the rest of the app: no separators
    /// of its own, no inset, and the page colour behind each row.
    private func ready(_ days: [DayOfMovements]) -> some View {
        List {
            if days.isEmpty {
                EmptyStateLine(String(localized: "transactions.empty", bundle: .module))
                    .plainRow()
            }

            ForEach(days) { day in
                Section {
                    ForEach(day.movements) { movement in
                        MovementRow(
                            entry: movement,
                            accountNames: model.accountNames,
                            moneyAccountIDs: model.moneyAccountIDs,
                            formatter: formatter
                        )
                        .plainRow()
                        .swipeActions(edge: .trailing) {
                            Button(
                                String(localized: "transactions.delete", bundle: .module),
                                role: .destructive
                            ) {
                                Task { await deletion.delete(movement) }
                            }
                        }
                        if movement.id != day.movements.last?.id {
                            Hairline().plainRow()
                        }
                    }
                } header: {
                    SectionCaption(caption(for: day.day)).plainRow()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
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
