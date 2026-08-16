import KeepworthDesignSystem
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

    enum Destination: Hashable {
        case summary
        case transactions
    }

    var body: some View {
        VStack(spacing: 0) {
            // The screens land here in the next two PRs; the shape of the bar is what this
            // one is for.
            Spacer()

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
                // Inert until phase 5 brings the movement editor. A button that opened an
                // empty sheet would be worse than one that waits.
                centerAction: {}
            )
        }
        .background(.bg)
    }
}
