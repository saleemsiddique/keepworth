import SwiftUI

/// One destination of `LedgerTabBar`, carrying the value it selects.
///
/// Generic over the tag so the bar never learns what the app's destinations are: naming them
/// here would put navigation inside the design system, and the two grow at different speeds.
public struct LedgerTabItem<Tag: Hashable> {
    let tag: Tag
    let title: String
    let symbolName: String

    public init(tag: Tag, title: String, symbolName: String) {
        self.tag = tag
        self.title = title
        self.symbolName = symbolName
    }
}

/// Two destinations with the add button at the exact centre.
///
/// The centre button is the **only** accented element in the bar. The selected destination is
/// `ink` and the other one `inkSoft`: green marks what you can do, not where you are.
///
/// There are two destinations because there are two, not because the type allows two. Growth
/// goes into the existing screens, never into a third tab.
public struct LedgerTabBar<Tag: Hashable>: View {
    @Binding private var selection: Tag
    private let leading: LedgerTabItem<Tag>
    private let trailing: LedgerTabItem<Tag>
    private let centerLabel: String
    private let centerAction: () -> Void

    /// `centerLabel` is read by VoiceOver and never drawn: the button is a symbol, and a
    /// symbol with no label is a button screen readers cannot announce.
    public init(
        selection: Binding<Tag>,
        leading: LedgerTabItem<Tag>,
        trailing: LedgerTabItem<Tag>,
        centerLabel: String,
        centerAction: @escaping () -> Void
    ) {
        self._selection = selection
        self.leading = leading
        self.trailing = trailing
        self.centerLabel = centerLabel
        self.centerAction = centerAction
    }

    public var body: some View {
        VStack(spacing: 0) {
            Hairline()

            HStack(spacing: 0) {
                destinationButton(leading)
                addButton
                destinationButton(trailing)
            }
            .padding(.vertical, Spacing.row)
        }
        .background(.bg)
    }

    private func destinationButton(_ item: LedgerTabItem<Tag>) -> some View {
        Button {
            selection = item.tag
        } label: {
            VStack(spacing: Spacing.withinLine) {
                Image(systemName: item.symbolName)
                    .fontWeight(.light)
                Text(item.title)
                    .font(.sectionCaption)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(item.tag == selection ? Color.ink : Color.inkSoft)
    }

    private var addButton: some View {
        Button(action: centerAction) {
            Image(systemName: "plus.circle")
                .font(.tabBarSymbol)
                .fontWeight(.light)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.accent)
        .accessibilityLabel(Text(centerLabel))
    }
}

private struct LedgerTabBarPreview: View {
    @State private var selection = 0

    var body: some View {
        VStack {
            Spacer()
            LedgerTabBar(
                selection: $selection,
                leading: LedgerTabItem(tag: 0, title: "Resumen", symbolName: "square.stack"),
                trailing: LedgerTabItem(tag: 1, title: "Movimientos", symbolName: "list.bullet"),
                centerLabel: "Añadir movimiento",
                centerAction: {}
            )
        }
        .background(.bg)
    }
}

#Preview("Light") {
    LedgerTabBarPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    LedgerTabBarPreview().preferredColorScheme(.dark)
}
