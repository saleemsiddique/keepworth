import FeatureSupport
import Foundation
import KeepworthDesignSystem
import KeepworthDomain
import SwiftUI

/// Recording a movement, and correcting one.
///
/// The most used screen of the app: the type on top, the figure it is about, the two pickers
/// that say where the money went, and the keypad under everything. Nothing scrolls out of
/// reach of a thumb because nothing here is optional except the payee and the note.
public struct MovementEditorView: View {
    @State private var model: MovementEditorModel
    private let formatter: MoneyFormatter
    private let dayFormat: Date.FormatStyle

    @Environment(\.dismiss) private var dismiss
    @State private var picking: Picking?

    public init(
        model: MovementEditorModel,
        formatter: MoneyFormatter,
        locale: Locale = .autoupdatingCurrent
    ) {
        self._model = State(initialValue: model)
        self.formatter = formatter
        self.dayFormat = CalendarDate.longDayStyle(in: locale)
    }

    /// Which picker is open. One value rather than a flag each, so two cannot be open at once.
    private enum Picking: Hashable {
        case account
        case counterpart
        case day
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.surface.ignoresSafeArea()

                switch model.state {
                case .loading:
                    EmptyView()
                case .ready:
                    ready
                case .failed:
                    failed
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    PrimaryAction(
                        String(localized: "editor.save", bundle: .module),
                        availability: model.availability
                    ) {
                        Task {
                            if await model.save() { dismiss() }
                        }
                    }
                }
                // The toolbar item, not the button, draws the glass capsule iOS puts behind a
                // bar control. This design system has no cards and no shadows.
                .sharedBackgroundVisibility(.hidden)
            }
            .navigationDestination(item: $picking) { picker($0) }
        }
        .task { await model.load() }
        .alert(
            Text("editor.saveFailed", bundle: .module),
            isPresented: failureIsShowing
        ) {
            Button(String(localized: "editor.ok", bundle: .module)) {
                model.dismissFailure()
            }
        }
    }

    private var title: Text {
        model.isCorrecting
            ? Text("editor.correct", bundle: .module)
            : Text("editor.new", bundle: .module)
    }

    private var failureIsShowing: Binding<Bool> {
        Binding(
            get: { model.lastFailure != nil },
            set: { isShowing in
                if !isShowing { model.dismissFailure() }
            }
        )
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: Spacing.betweenSections) {
            ChoiceBar(
                selection: $model.type,
                items: [
                    ChoiceItem(
                        tag: MovementType.expense,
                        title: String(localized: "editor.expense", bundle: .module)
                    ),
                    ChoiceItem(
                        tag: MovementType.income,
                        title: String(localized: "editor.income", bundle: .module)
                    ),
                    ChoiceItem(
                        tag: MovementType.transfer,
                        title: String(localized: "editor.transfer", bundle: .module)
                    ),
                ]
            )

            HeadlineAmount(
                caption: String(localized: "editor.amount", bundle: .module),
                amount: formatter.string(for: model.typedAmount)
            )

            fields

            Spacer(minLength: 0)

            AmountKeypad(
                onDigit: { model.amount.append($0) },
                onDelete: { model.amount.deleteLast() }
            )
        }
        .padding(Spacing.screenMargin)
    }

    private var fields: some View {
        VStack(spacing: 0) {
            FormRow(title: accountLabel, value: name(of: model.accountID)) {
                picking = .account
            }
            Hairline()
            FormRow(title: counterpartLabel, value: name(of: model.counterpartID)) {
                picking = .counterpart
            }
            Hairline()
            FormRow(
                title: String(localized: "editor.date", bundle: .module),
                value: model.occurredOn.formatted(dayFormat)
            ) {
                picking = .day
            }
            Hairline()
            // A transfer between the user's own accounts has no payee: both sides are theirs,
            // and the row would ask a question with no answer.
            if model.type != .transfer {
                TextEntryRow(
                    title: String(localized: "editor.payee", bundle: .module),
                    prompt: String(localized: "editor.optional", bundle: .module),
                    text: $model.payee
                )
            }
        }
    }

    /// The labels change with the type because the same two rows mean different things: an
    /// expense leaves an account and lands on a category, a transfer leaves one account for
    /// another.
    private var accountLabel: String {
        switch model.type {
        case .expense, .transfer: String(localized: "editor.from", bundle: .module)
        case .income: String(localized: "editor.into", bundle: .module)
        }
    }

    private var counterpartLabel: String {
        switch model.type {
        case .expense: String(localized: "editor.category", bundle: .module)
        case .income: String(localized: "editor.source", bundle: .module)
        case .transfer: String(localized: "editor.to", bundle: .module)
        }
    }

    private func name(of id: AccountID?) -> String {
        model.account(withID: id)?.name
            ?? String(localized: "editor.choose", bundle: .module)
    }

    @ViewBuilder
    private func picker(_ picking: Picking) -> some View {
        switch picking {
        case .account:
            accountPicker(model.moneyAccounts, chosen: model.accountID, title: accountLabel) {
                model.accountID = $0
            }
        case .counterpart:
            accountPicker(
                model.counterparts,
                chosen: model.counterpartID,
                title: counterpartLabel
            ) {
                model.counterpartID = $0
            }
        case .day:
            dayPicker
        }
    }

    private func accountPicker(
        _ options: [Account],
        chosen: AccountID?,
        title: String,
        onPick: @escaping (AccountID) -> Void
    ) -> some View {
        ZStack {
            Color.surface.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if options.isEmpty {
                        EmptyStateLine(String(localized: "editor.noOptions", bundle: .module))
                    }

                    ForEach(options) { option in
                        SelectionRow(
                            tag: option.id,
                            selection: chosen,
                            title: option.name,
                            symbolName: option.symbolName
                        ) {
                            onPick(option.id)
                            picking = nil
                        }
                        if option.id != options.last?.id {
                            Hairline()
                        }
                    }
                }
                .padding(Spacing.screenMargin)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The system date picker, which is the one control here that would be worse rebuilt: it
    /// is what every other app on the phone taught the user to expect.
    private var dayPicker: some View {
        ZStack {
            Color.surface.ignoresSafeArea()

            DatePicker(
                String(localized: "editor.date", bundle: .module),
                selection: chosenDay,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(.accent)
            .padding(Spacing.screenMargin)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle(Text("editor.date", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Noon UTC in both directions, which is what keeps a day from sliding either way: a
    /// `CalendarDate` has no zone, and any other hour lands on the neighbouring day somewhere.
    private var chosenDay: Binding<Date> {
        Binding(
            get: { model.occurredOn.noonUTC ?? Date() },
            set: { picked in
                var utc = Calendar(identifier: .gregorian)
                utc.timeZone = .gmt
                model.occurredOn = CalendarDate(picked, in: utc)
            }
        )
    }

    private var failed: some View {
        VStack(spacing: Spacing.row) {
            Text("editor.failed", bundle: .module)
                .font(.rowTitle)
                .foregroundStyle(.ink)
                .multilineTextAlignment(.center)
            PrimaryAction(String(localized: "editor.retry", bundle: .module)) {
                Task { await model.load() }
            }
        }
        .padding(Spacing.screenMargin)
    }
}
