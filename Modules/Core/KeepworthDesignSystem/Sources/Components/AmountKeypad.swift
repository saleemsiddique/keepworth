import SwiftUI

/// The ten digits and a delete key, for typing an amount.
///
/// Its own keypad rather than a text field with the numeric keyboard: the amount is built out
/// of `DigitAmount`, so it is always a whole figure and never a string somebody has to parse.
/// The system keyboard would also cover the very rows the user is choosing between.
///
/// It emits keys and holds nothing. What the digits add up to belongs to the screen, which is
/// the only place that knows the currency they are counted in.
public struct AmountKeypad: View {
    private let onDigit: (Int) -> Void
    private let onDelete: () -> Void

    /// Only exists to give `sensoryFeedback` something that changes on every key.
    @State private var keyCount = 0

    public init(onDigit: @escaping (Int) -> Void, onDelete: @escaping () -> Void) {
        self.onDigit = onDigit
        self.onDelete = onDelete
    }

    public var body: some View {
        Grid(horizontalSpacing: Spacing.withinBlock, verticalSpacing: Spacing.withinBlock) {
            ForEach(Self.rows, id: \.first) { row in
                GridRow {
                    ForEach(row, id: \.self) { digit in
                        key(digit)
                    }
                }
            }
            GridRow {
                // The empty cell keeps the zero centred under the 8, where a thumb expects it.
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                key(0)
                deleteKey
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: keyCount)
    }

    private static let rows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    private func key(_ digit: Int) -> some View {
        Button {
            keyCount += 1
            onDigit(digit)
        } label: {
            Text(digit.formatted())
                .font(.headlineAmount)
                .foregroundStyle(.ink)
                .frame(maxWidth: .infinity, minHeight: Spacing.minimumTapTarget)
        }
        .buttonStyle(.plain)
    }

    private var deleteKey: some View {
        Button {
            keyCount += 1
            onDelete()
        } label: {
            Image(systemName: "delete.left")
                .font(.rowTitle)
                .fontWeight(.light)
                .foregroundStyle(.inkSoft)
                .frame(maxWidth: .infinity, minHeight: Spacing.minimumTapTarget)
        }
        .buttonStyle(.plain)
    }
}

private struct AmountKeypadPreview: View {
    @State private var amount = DigitAmount()

    var body: some View {
        VStack(spacing: Spacing.betweenSections) {
            HeadlineAmount(caption: "Importe", amount: "\(amount.minorUnits)")
            AmountKeypad(
                onDigit: { amount.append($0) },
                onDelete: { amount.deleteLast() }
            )
        }
        .padding(Spacing.screenMargin)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.bg)
    }
}

#Preview("Light") {
    AmountKeypadPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    AmountKeypadPreview().preferredColorScheme(.dark)
}
