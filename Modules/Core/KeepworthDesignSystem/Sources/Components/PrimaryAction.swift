import SwiftUI

/// Whether the one action of a screen can be taken yet.
///
/// An enum and not a boolean, for the reason `AmountDirection` is one: this module has no
/// flag parameters, and `PrimaryAction("Guardar", availability: .unavailable)` says at the
/// call site what `true` would have left to guess.
public enum ActionAvailability: Hashable, Sendable {
    /// Ready. Accent green, and the tap goes through.
    case available
    /// Something is still missing. `inkSoft`, and the tap does nothing.
    case unavailable
}

/// The single primary action of a screen. Everything else lives in native gestures: swipe,
/// long press, pull to dismiss.
///
/// One light haptic on tap, and no more: a second confirmation elsewhere in the same flow turns
/// feedback into noise.
///
/// An unavailable action stays on screen rather than disappearing. It shows there is a way
/// out of the form from the first moment, and the header does not change shape as the last
/// field gets filled in.
public struct PrimaryAction: View {
    private let title: String
    private let availability: ActionAvailability
    private let action: () -> Void

    /// Only exists to give `sensoryFeedback` something that changes on every tap.
    @State private var tapCount = 0

    public init(
        _ title: String,
        availability: ActionAvailability = .available,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.availability = availability
        self.action = action
    }

    public var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            Text(title)
                .font(.primaryAction)
                .foregroundStyle(availability == .available ? Color.accent : Color.inkSoft)
        }
        .buttonStyle(.plain)
        .disabled(availability == .unavailable)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }
}

private struct PrimaryActionPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.betweenSections) {
            PrimaryAction("Guardar") {}
            PrimaryAction("Guardar", availability: .unavailable) {}
        }
        .padding(Spacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.bg)
    }
}

#Preview("Light") {
    PrimaryActionPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    PrimaryActionPreview().preferredColorScheme(.dark)
}
