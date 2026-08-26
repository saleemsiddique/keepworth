import KeepworthDesignSystem
import SwiftUI

extension View {
    /// Strips a `List` row of everything that would make it look like a `List`: its separator,
    /// its inset and its background.
    ///
    /// The app's rows bring their own spacing and their own hairlines, and `List` is used for
    /// the one screen that needs swipe actions and unbounded length — not for the look, which
    /// has to stay the same as every screen built on a `ScrollView`.
    public func plainRow() -> some View {
        listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: 0,
                    leading: Spacing.screenMargin,
                    bottom: 0,
                    trailing: Spacing.screenMargin
                )
            )
            .listRowBackground(Color.bg)
    }
}
