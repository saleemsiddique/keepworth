import SwiftUI

/// The chrome of a modal sheet: a title, the content, and the one action that finishes it.
///
/// The only place `surface` is used, which is what the token was defined for — a sheet sits
/// on top of the page and has to read as a layer above it, and that is the whole of the
/// difference. Still no card and no shadow.
///
/// **There is no cancel button.** Leaving without saving is the native pull-to-dismiss, the
/// same rule that puts delete in a swipe: one primary action per screen and the rest in
/// gestures the system already taught.
public struct SheetSurface<Content: View>: View {
    private let title: String
    private let actionTitle: String
    private let availability: ActionAvailability
    private let action: () -> Void
    private let content: Content

    public init(
        title: String,
        actionTitle: String,
        availability: ActionAvailability = .available,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.availability = availability
        self.action = action
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.betweenSections) {
            HStack(spacing: Spacing.withinBlock) {
                Text(title)
                    .font(.rowTitle)
                    .foregroundStyle(.ink)

                Spacer(minLength: Spacing.withinBlock)

                PrimaryAction(actionTitle, availability: availability, action: action)
            }

            content
        }
        .padding(Spacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.surface)
    }
}

private struct SheetSurfacePreview: View {
    @State private var payee = ""

    var body: some View {
        SheetSurface(title: "Nuevo movimiento", actionTitle: "Guardar", action: {}) {
            VStack(spacing: 0) {
                FormRow(title: "Cuenta", value: "Efectivo") {}
                Hairline()
                FormRow(title: "Categoría", value: "Supermercado") {}
                Hairline()
                TextEntryRow(title: "Beneficiario", prompt: "Opcional", text: $payee)
            }
        }
    }
}

#Preview("Light") {
    SheetSurfacePreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    SheetSurfacePreview().preferredColorScheme(.dark)
}
