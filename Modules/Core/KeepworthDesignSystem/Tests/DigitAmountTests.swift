import Testing

@testable import KeepworthDesignSystem

/// The amount being typed is the one piece of logic in this module, and the one place where a
/// mistake would be about money rather than about looks.

@Test("Digits accumulate into minor units as they are typed")
func digitsAccumulate() {
    var amount = DigitAmount()

    amount.append(4)
    #expect(amount.minorUnits == 4)
    amount.append(2)
    #expect(amount.minorUnits == 42)
    amount.append(3)
    #expect(amount.minorUnits == 423)
    amount.append(0)
    #expect(amount.minorUnits == 4230)
}

@Test("A new amount is zero")
func startsAtZero() {
    #expect(DigitAmount().isZero)
    #expect(DigitAmount().minorUnits == 0)
}

@Test("Leading zeroes do not grow the amount")
func leadingZeroesDoNothing() {
    var amount = DigitAmount()

    amount.append(0)
    amount.append(0)

    #expect(amount.isZero)
}

@Test("Deleting drops the last digit typed")
func deleteDropsTheLastDigit() {
    var amount = DigitAmount(minorUnits: 4230)

    amount.deleteLast()
    #expect(amount.minorUnits == 423)
    amount.deleteLast()
    #expect(amount.minorUnits == 42)
}

@Test("Deleting on an empty amount is safe, so holding the key is too")
func deleteOnZeroDoesNothing() {
    var amount = DigitAmount()

    amount.deleteLast()
    amount.deleteLast()

    #expect(amount.isZero)
}

@Test("Anything that is not a digit is ignored")
func ignoresNonDigits() {
    var amount = DigitAmount(minorUnits: 42)

    amount.append(-1)
    amount.append(10)

    #expect(amount.minorUnits == 42)
}

/// Wrapping past `Int64` would turn a very long press into a negative amount, which is the
/// one failure here that would be about money.
@Test("An amount that would not fit stops growing instead of wrapping")
func refusesToOverflow() {
    var amount = DigitAmount(minorUnits: Int64.max / 10 + 1)
    let before = amount.minorUnits

    amount.append(9)

    #expect(amount.minorUnits == before)
}

@Test("A digit that would not fit by one is refused too")
func refusesToOverflowOnTheLastDigit() {
    var amount = DigitAmount(minorUnits: 922_337_203_685_477_580)
    #expect(amount.minorUnits * 10 + 7 == Int64.max)

    amount.append(8)

    #expect(amount.minorUnits == 922_337_203_685_477_580)
}
