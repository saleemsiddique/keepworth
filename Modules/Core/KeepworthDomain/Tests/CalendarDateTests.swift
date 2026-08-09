import Testing

@testable import KeepworthDomain

@Test("A valid date keeps its three components")
func keepsItsComponents() throws {
    let date = try CalendarDate(year: 2026, month: 1, day: 31)

    #expect(date.year == 2026)
    #expect(date.month == 1)
    #expect(date.day == 31)
}

@Test("A month out of range is rejected", arguments: [0, 13, -1])
func rejectsMonthOutOfRange(month: Int) {
    #expect(throws: CalendarDateError.monthOutOfRange(month)) {
        try CalendarDate(year: 2026, month: month, day: 1)
    }
}

@Test("A day that month does not have is rejected")
func rejectsDayThatMonthDoesNotHave() {
    #expect(throws: CalendarDateError.dayOutOfRange(31, month: 4, year: 2026)) {
        try CalendarDate(year: 2026, month: 4, day: 31)
    }
}

@Test("29 February exists in a leap year")
func acceptsLeapDayInLeapYear() throws {
    #expect(try CalendarDate(year: 2024, month: 2, day: 29).day == 29)
}

@Test("29 February does not exist in a common year")
func rejectsLeapDayInCommonYear() {
    #expect(throws: CalendarDateError.dayOutOfRange(29, month: 2, year: 2026)) {
        try CalendarDate(year: 2026, month: 2, day: 29)
    }
}

@Test("The full Gregorian leap year rule applies")
func appliesFullGregorianLeapRule() {
    // 2000 is a leap year by the 400 rule; 1900 is not, by the 100 rule.
    #expect(CalendarDate.isLeapYear(2000))
    #expect(!CalendarDate.isLeapYear(1900))
    #expect(CalendarDate.isLeapYear(2024))
    #expect(!CalendarDate.isLeapYear(2026))
}

@Test("The textual form is ISO 8601 with leading zeros")
func rendersAsIso8601() throws {
    #expect(try CalendarDate(year: 2026, month: 1, day: 5).description == "2026-01-05")
    #expect(try CalendarDate(year: 999, month: 12, day: 31).description == "0999-12-31")
}

@Test("Reading and writing the ISO 8601 form returns the same date")
func roundTripsThroughIso8601() throws {
    let original = try CalendarDate(year: 2026, month: 2, day: 28)

    #expect(try CalendarDate(iso8601: original.description) == original)
}

@Test(
    "Text that is not yyyy-MM-dd is rejected",
    arguments: ["2026-1-31", "31-01-2026", "2026/01/31", "2026-01", "", "hoy"]
)
func rejectsMalformedText(text: String) {
    #expect(throws: CalendarDateError.malformedText(text)) {
        try CalendarDate(iso8601: text)
    }
}

@Test("Well-formed text holding an impossible date is rejected")
func rejectsImpossibleDateInWellFormedText() {
    #expect(throws: CalendarDateError.dayOutOfRange(31, month: 2, year: 2026)) {
        try CalendarDate(iso8601: "2026-02-31")
    }
}

@Test("Dates order by year, month and day")
func ordersChronologically() throws {
    let last = try CalendarDate(year: 2026, month: 1, day: 31)
    let first = try CalendarDate(year: 2025, month: 12, day: 31)
    let middle = try CalendarDate(year: 2026, month: 1, day: 1)

    #expect([last, first, middle].sorted() == [first, middle, last])
}

@Test("Ordering by the textual form matches ordering by date")
func textualOrderMatchesChronologicalOrder() throws {
    // This is what lets the schema's TEXT column sort in SQL without conversions.
    let dates = try [
        CalendarDate(year: 2026, month: 10, day: 1),
        CalendarDate(year: 2026, month: 2, day: 9),
        CalendarDate(year: 2025, month: 12, day: 31),
    ]

    #expect(dates.sorted().map(\.description) == dates.map(\.description).sorted())
}
