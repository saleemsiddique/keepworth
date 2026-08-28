import SwiftUI

/// A row in a list you pick one thing from: which account, which category, which bank.
///
/// Generic over the tag and told what is selected, rather than told whether it is the one —
/// the same shape `LedgerTabBar` and `ChoiceBar` use, and the reason this module still has no
/// boolean parameters. `selection` is optional because a list can legitimately start with
/// nothing picked.
///
/// The tick is the only accented element, and it is the one place in the app where green
/// marks a state rather than a direction: nothing moved, so no amount is being coloured.
public struct SelectionRow<Tag: Hashable>: View {
    private let tag: Tag
    private let selection: Tag?
    private let title: String
    private let subtitle: String?
    private let symbolName: String?
    private let action: () -> Void

    public init(
        tag: Tag,
        selection: Tag?,
        title: String,
        subtitle: String? = nil,
        symbolName: String? = nil,
        action: @escaping () -> Void
    ) {
        self.tag = tag
        self.selection = selection
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.withinBlock) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.rowSubtitle)
                        .fontWeight(.light)
                        .foregroundStyle(.inkSoft)
                }

                VStack(alignment: .leading, spacing: Spacing.withinLine) {
                    Text(title)
                        .font(.rowTitle)
                        .foregroundStyle(.ink)

                    if let subtitle {
                        Text(subtitle)
                            .font(.rowSubtitle)
                            .foregroundStyle(.inkSoft)
                    }
                }

                Spacer(minLength: Spacing.withinBlock)

                // Drawn whether or not it is ticked, so the titles do not shift sideways as
                // the selection moves down the list.
                Image(systemName: "checkmark")
                    .font(.rowSubtitle)
                    .foregroundStyle(isSelected ? Color.accent : Color.clear)
            }
            .padding(.vertical, Spacing.row)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var isSelected: Bool { tag == selection }
}

private struct SelectionRowPreview: View {
    @State private var selection: String? = "Efectivo"

    var body: some View {
        VStack(spacing: 0) {
            row("Efectivo", symbol: "banknote")
            Hairline()
            row("BBVA · Nómina", symbol: "building.columns")
            Hairline()
            row("Visa", symbol: "creditcard")
        }
        .padding(.horizontal, Spacing.screenMargin)
        .background(.bg)
    }

    private func row(_ title: String, symbol: String) -> some View {
        SelectionRow(tag: title, selection: selection, title: title, symbolName: symbol) {
            selection = title
        }
    }
}

#Preview("Light") {
    SelectionRowPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    SelectionRowPreview().preferredColorScheme(.dark)
}
