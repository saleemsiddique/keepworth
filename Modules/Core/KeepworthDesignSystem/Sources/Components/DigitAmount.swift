/// An amount being typed, held as the minor units it already adds up to.
///
/// Typing 4, 2, 3, 0 reads 0,04 then 0,42 then 4,23 then 42,30. The figure is never in a
/// half-written state, so there is nothing to parse and nothing to reject: no stray second
/// separator, no comma where a point was expected, no empty field standing for zero.
///
/// A type of its own rather than state inside the keypad, so what it does can be asserted.
/// The design system cannot see `Money`, so this counts in `Int64` and whoever owns it turns
/// that into an amount in a currency.
public struct DigitAmount: Hashable, Sendable {
    public private(set) var minorUnits: Int64

    public init(minorUnits: Int64 = 0) {
        self.minorUnits = minorUnits
    }

    public var isZero: Bool { minorUnits == 0 }

    /// Ignores anything that is not a single digit, and ignores a digit that would not fit.
    ///
    /// Silently, on purpose: the alternative is an error nobody can act on. Someone typing
    /// past ninety quadrillion has held the key down, and the right answer to that is for the
    /// figure to stop growing rather than to wrap around into a negative one.
    public mutating func append(_ digit: Int) {
        guard (0...9).contains(digit) else { return }
        let (shifted, overflowed) = minorUnits.multipliedReportingOverflow(by: 10)
        guard !overflowed else { return }
        let (grown, grewPastTheEnd) = shifted.addingReportingOverflow(Int64(digit))
        guard !grewPastTheEnd else { return }
        minorUnits = grown
    }

    /// Drops the last digit typed. On an amount that is already zero it does nothing, which
    /// is what makes holding the delete key safe.
    public mutating func deleteLast() {
        minorUnits /= 10
    }
}
