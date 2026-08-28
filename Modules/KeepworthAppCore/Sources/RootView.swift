import FeatureMovementEditor
import FeatureSettings
import FeatureSummary
import FeatureSupport
import FeatureTransactions
import KeepworthDesignSystem
import KeepworthDomain
import SwiftUI

/// The app's root view: opens the ledger, seeds it if it is new, and shows the two
/// destinations.
public struct RootView: View {
    @State private var launch: LaunchState = .opening

    public init() {}

    public var body: some View {
        Group {
            switch launch {
            case .opening:
                opening
            case .ready(let dependencies):
                LedgerTabs(dependencies: dependencies)
            case .failed:
                failed
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.bg)
        .task {
            await open()
        }
    }

    private var opening: some View {
        Text("root.loading", bundle: .module)
            .font(.rowSubtitle)
            .foregroundStyle(.inkSoft)
    }

    private var failed: some View {
        VStack(spacing: Spacing.row) {
            Text("root.failed", bundle: .module)
                .font(.rowTitle)
                .foregroundStyle(.ink)
                .multilineTextAlignment(.center)

            PrimaryAction(String(localized: "root.retry", bundle: .module)) {
                launch = .opening
                Task { await open() }
            }
        }
        .padding(Spacing.screenMargin)
    }

    /// Detached on purpose. Opening the database runs the migrations and starts the change
    /// observation, and that one blocks until it can take write access — on the main actor it
    /// would freeze the first frame.
    private func open() async {
        let opened = await Task.detached(priority: .userInitiated) { () -> Dependencies? in
            guard let dependencies = try? Dependencies.live() else { return nil }
            guard (try? await FirstLaunch.prepareIfNeeded(dependencies)) != nil else { return nil }
            return dependencies
        }.value

        launch = opened.map(LaunchState.ready) ?? .failed
    }
}

private enum LaunchState {
    case opening
    case ready(Dependencies)
    case failed
}

/// The two destinations, with the add button dead centre.
private struct LedgerTabs: View {
    let dependencies: Dependencies

    @State private var selection: Destination = .summary
    @State private var isShowingSettings = false
    /// Which movement the editor is open on, or `.new` for one that does not exist yet. One
    /// value rather than a flag plus an entry, so "open" and "on what" cannot disagree.
    @State private var editing: Editing?

    private enum Editing: Hashable, Identifiable {
        case new
        case correcting(Entry)

        var id: EntryID? {
            switch self {
            case .new: nil
            case .correcting(let entry): entry.id
            }
        }

        var entry: Entry? {
            switch self {
            case .new: nil
            case .correcting(let entry): entry
            }
        }
    }

    enum Destination: Hashable {
        case summary
        case transactions
    }

    var body: some View {
        VStack(spacing: 0) {
            switch selection {
            case .summary:
                NavigationStack {
                    SummaryView(
                        model: SummaryModel(
                            institutions: dependencies.institutions,
                            accounts: dependencies.accounts,
                            entries: dependencies.entries,
                            settings: dependencies.settings,
                            changes: dependencies.changes
                        ),
                        deletion: MovementDeletion(entries: dependencies.entries),
                        formatter: dependencies.formatter,
                        onSelect: open
                    )
                    // Mounted here and not inside `SummaryView`: a feature never imports
                    // another feature, so the summary cannot know `FeatureSettings` exists.
                    // The composition root is the only place that knows both.
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                isShowingSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .fontWeight(.light)
                                    .foregroundStyle(.ink)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                Text("settings.open", bundle: .module)
                            )
                        }
                        // The toolbar item, not the button, is what draws the glass capsule
                        // iOS puts behind a bar control. This design system has no cards and
                        // no shadows, and a toolbar is not an exception to that.
                        .sharedBackgroundVisibility(.hidden)
                    }
                }
            case .transactions:
                NavigationStack {
                    TransactionsView(
                        model: TransactionsModel(
                            accounts: dependencies.accounts,
                            entries: dependencies.entries,
                            changes: dependencies.changes
                        ),
                        deletion: MovementDeletion(entries: dependencies.entries),
                        formatter: dependencies.formatter,
                        onSelect: open
                    )
                }
            }

            LedgerTabBar(
                selection: $selection,
                leading: LedgerTabItem(
                    tag: Destination.summary,
                    title: String(localized: "tab.summary", bundle: .module),
                    symbolName: "square.stack"
                ),
                trailing: LedgerTabItem(
                    tag: Destination.transactions,
                    title: String(localized: "tab.transactions", bundle: .module),
                    symbolName: "list.bullet"
                ),
                centerLabel: String(localized: "tab.add", bundle: .module),
                centerAction: { editing = .new }
            )
        }
        .background(.bg)
        .sheet(isPresented: $isShowingSettings) {
            settings
        }
        .sheet(item: $editing) { editor(for: $0) }
    }

    /// A starting balance is not opened. Its counterpart is the internal equity account, which
    /// appears in no picker, so the editor could not represent it — and saving it as anything
    /// else would turn it into a movement the user never made.
    private func open(_ entry: Entry) {
        editing = .correcting(entry)
    }

    private func editor(for editing: Editing) -> some View {
        MovementEditorView(
            model: MovementEditorModel(
                editing: editing.entry,
                accounts: dependencies.accounts,
                entries: dependencies.entries,
                settings: dependencies.settings
            ),
            formatter: dependencies.formatter
        )
        .presentationDetents([.large])
    }

    /// Built when the sheet opens rather than held alongside the tabs, so its observation of
    /// the ledger lasts exactly as long as the screen does.
    private var settings: some View {
        SettingsView(
            model: SettingsModel(
                institutions: dependencies.institutions,
                accounts: dependencies.accounts,
                settings: dependencies.settings,
                changes: dependencies.changes
            ),
            dependencies: SettingsDependencies(
                institutions: dependencies.institutions,
                accounts: dependencies.accounts,
                entries: dependencies.entries,
                formatter: dependencies.formatter
            )
        )
    }
}
