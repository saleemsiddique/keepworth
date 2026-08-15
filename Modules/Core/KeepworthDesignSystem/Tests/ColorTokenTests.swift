import Testing
import UIKit

@testable import KeepworthDesignSystem

/// UIKit lives here and nowhere else in this module. `Color("typo", bundle:)` never fails: it
/// hands back a placeholder, so a missing or misspelled asset would ship silently. `UIColor`
/// is the only API that admits it could not find the colour, which is what makes these tests
/// worth writing.

/// The values documented in `ESTADO.md` §7 and in this module's `CLAUDE.md`. Repeated here on
/// purpose: a test that reads the same source as the code under test proves nothing.
struct ColorToken: Sendable, CustomStringConvertible {
    let name: String
    let light: UInt32
    let dark: UInt32

    var description: String { name }
}

let colorTokens = [
    ColorToken(name: "bg", light: 0xF7_F7F5, dark: 0x00_0000),
    ColorToken(name: "surface", light: 0xFF_FFFF, dark: 0x0D_0D0C),
    ColorToken(name: "ink", light: 0x14_1413, dark: 0xF2_F2EF),
    ColorToken(name: "inkSoft", light: 0x6E_6E69, dark: 0x8A_8A85),
    ColorToken(name: "hairline", light: 0xE2_E2DC, dark: 0x23_2322),
    ColorToken(name: "accent", light: 0x1E_9E5A, dark: 0x30_D158),
]

@Test("Every colour token ships and resolves to its documented values", arguments: colorTokens)
func colorTokenResolvesToBothDocumentedValues(token: ColorToken) throws {
    // `#require` is the "is it even there" assertion: a missing or misspelled asset stops the
    // case here with the token's name in the message.
    let color = try #require(UIColor(named: token.name, in: .module, compatibleWith: nil))

    #expect(hexValue(of: color, in: .light) == token.light)
    // Without a dark variant the asset still loads and both styles resolve to the light
    // value, so this is the assertion that catches a half-written colour set.
    #expect(hexValue(of: color, in: .dark) == token.dark)

    // A token is never translucent. Left out, an `"alpha": "0.500"` slipped into a colour set
    // would pass every check above and only show up layered over something else.
    #expect(alpha(of: color, in: .light) == 1)
    #expect(alpha(of: color, in: .dark) == 1)
}

private func hexValue(of color: UIColor, in style: UIUserInterfaceStyle) -> UInt32 {
    let components = components(of: color, in: style)
    return eightBitChannel(components.red) << 16
        | eightBitChannel(components.green) << 8
        | eightBitChannel(components.blue)
}

private func alpha(of color: UIColor, in style: UIUserInterfaceStyle) -> CGFloat {
    components(of: color, in: style).alpha
}

private func components(
    of color: UIColor,
    in style: UIUserInterfaceStyle
) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
    let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))

    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

    return (red, green, blue, alpha)
}

/// Rounds to the 8 bits the asset catalog stores, so the comparison is exact instead of a
/// floating point tolerance.
private func eightBitChannel(_ value: CGFloat) -> UInt32 {
    UInt32((value * 255).rounded())
}
