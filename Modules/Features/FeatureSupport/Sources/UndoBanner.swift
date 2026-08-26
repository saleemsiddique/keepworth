import KeepworthDesignSystem
import SwiftUI

/// The strip that says what was removed and offers to put it back.
///
/// Both texts arrive already localised: `FeatureSupport` has no String Catalog, for the same
/// reason the design system has none — it does not know which language is on screen.
public struct UndoBanner: View {
    private let message: String
    private let undoTitle: String
    private let undo: () -> Void

    public init(message: String, undoTitle: String, undo: @escaping () -> Void) {
        self.message = message
        self.undoTitle = undoTitle
        self.undo = undo
    }

    public var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack {
                Text(message)
                    .font(.rowSubtitle)
                    .foregroundStyle(.inkSoft)
                Spacer()
                PrimaryAction(undoTitle, action: undo)
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.row)
        }
        .background(.bg)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct UndoBannerPreview: View {
    var body: some View {
        VStack {
            Spacer()
            UndoBanner(message: "Movimiento borrado", undoTitle: "Deshacer") {}
        }
        .background(.bg)
    }
}

#Preview("Light") {
    UndoBannerPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    UndoBannerPreview().preferredColorScheme(.dark)
}
