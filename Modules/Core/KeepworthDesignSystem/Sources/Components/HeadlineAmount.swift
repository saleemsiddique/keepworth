import SwiftUI

/// The one figure that headlines a screen, with its caption above and an optional line under it.
///
/// `amount` and `detail` arrive already formatted. This module cannot see `Money`, and that is
/// deliberate: turning minor units into text needs a currency and a locale, which are the
/// caller's business, not the design system's.
///
/// It does not hide itself either. Tapping net worth to redact it is a screen's state, so the
/// caller owns the gesture and applies `.redacted(reason: .placeholder)`.
public struct HeadlineAmount: View {
    private let caption: String
    private let amount: String
    private let detail: String?

    public init(caption: String, amount: String, detail: String? = nil) {
        self.caption = caption
        self.amount = amount
        self.detail = detail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.withinBlock) {
            SectionCaption(caption)

            Text(amount)
                .font(.headlineAmount)
                .foregroundStyle(.ink)
                // Digits roll instead of blinking when the figure is recomputed.
                .contentTransition(.numericText())

            if let detail {
                Text(detail)
                    .font(.rowSubtitle)
                    .foregroundStyle(.inkSoft)
            }
        }
    }
}

private struct HeadlineAmountPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.betweenSections) {
            HeadlineAmount(
                caption: "Patrimonio",
                amount: "24.560,80 €",
                detail: "▲ +1,2 % este mes"
            )
            HeadlineAmount(caption: "Ahorrado", amount: "+1.162,70 €")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.screenMargin)
        .background(.bg)
    }
}

#Preview("Light") {
    HeadlineAmountPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    HeadlineAmountPreview().preferredColorScheme(.dark)
}
