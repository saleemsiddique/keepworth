import SwiftUI

/// The single primary action of a screen. Everything else lives in native gestures: swipe,
/// long press, pull to dismiss.
///
/// One light haptic on tap, and no more: a second confirmation elsewhere in the same flow turns
/// feedback into noise.
public struct PrimaryAction: View {
    private let title: String
    private let action: () -> Void

    /// Only exists to give `sensoryFeedback` something that changes on every tap.
    @State private var tapCount = 0

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            Text(title)
                .font(.primaryAction)
                .foregroundStyle(.accent)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }
}

private struct PrimaryActionPreview: View {
    var body: some View {
        PrimaryAction("Guardar") {}
            .padding(Spacing.screenMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.bg)
    }
}

#Preview("Light") {
    PrimaryActionPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    PrimaryActionPreview().preferredColorScheme(.dark)
}
