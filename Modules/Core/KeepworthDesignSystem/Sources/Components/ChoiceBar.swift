import SwiftUI

/// One option of `ChoiceBar`, carrying the value it selects.
///
/// Generic over the tag for the same reason `LedgerTabItem` is: the design system does not
/// learn what an expense or a transfer is.
public struct ChoiceItem<Tag: Hashable> {
    let tag: Tag
    let title: String

    public init(tag: Tag, title: String) {
        self.tag = tag
        self.title = title
    }
}

/// A row of mutually exclusive options, for the kind of thing being recorded.
///
/// No segmented control: that one draws a filled capsule and a border, which is the card this
/// app does not have. What marks the choice here is weight and `ink` against `inkSoft`, plus
/// a hairline under the option that is on — the same rule as the tab bar, where green says
/// what you can do and not where you are.
public struct ChoiceBar<Tag: Hashable>: View {
    @Binding private var selection: Tag
    private let items: [ChoiceItem<Tag>]

    public init(selection: Binding<Tag>, items: [ChoiceItem<Tag>]) {
        self._selection = selection
        self.items = items
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tag) { item in
                option(item)
            }
        }
    }

    private func option(_ item: ChoiceItem<Tag>) -> some View {
        let isSelected = item.tag == selection
        return Button {
            selection = item.tag
        } label: {
            VStack(spacing: Spacing.withinBlock) {
                Text(item.title)
                    .font(.rowTitle)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.ink : Color.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: Spacing.minimumTapTarget)

                // Full width under the chosen option, invisible under the others: drawing it
                // only when selected would make the row jump by half a point as it moves.
                Rectangle()
                    .fill(isSelected ? Color.ink : Color.clear)
                    .frame(height: Spacing.hairline)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct ChoiceBarPreview: View {
    @State private var selection = 0

    var body: some View {
        ChoiceBar(
            selection: $selection,
            items: [
                ChoiceItem(tag: 0, title: "Gasto"),
                ChoiceItem(tag: 1, title: "Ingreso"),
                ChoiceItem(tag: 2, title: "Traspaso"),
            ]
        )
        .padding(.horizontal, Spacing.screenMargin)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.bg)
    }
}

#Preview("Light") {
    ChoiceBarPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    ChoiceBarPreview().preferredColorScheme(.dark)
}
