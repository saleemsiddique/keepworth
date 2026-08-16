/// A calendar date with no time and no time zone: "31 January 2026" and nothing else.
///
/// Not an instant. A `Date` stands for a different day depending on the zone reading it,
/// so the same expense would land in a different month and two synced devices would show
/// different reports. The time zone only comes in when the UI decides what day today is.
public struct CalendarDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) throws {
        guard (1...9999).contains(year) else {
            throw CalendarDateError.yearOutOfRange(year)
        }
        guard (1...12).contains(month) else {
            throw CalendarDateError.monthOutOfRange(month)
        }
        guard (1...Self.daysInMonth(month, ofYear: year)).contains(day) else {
            throw CalendarDateError.dayOutOfRange(day, month: month, year: year)
        }
        self.year = year
        self.month = month
        self.day = day
    }

    public init(iso8601 text: String) throws {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
            parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else {
            throw CalendarDateError.malformedText(text)
        }
        try self.init(year: year, month: month, day: day)
    }

    /// ISO 8601 `yyyy-MM-dd`: the schema's `TEXT` column, and sorting it as a string gives
    /// the same order as sorting it as a date.
    public var description: String {
        "\(Self.padded(year, toWidth: 4))-\(Self.padded(month, toWidth: 2))-\(Self.padded(day, toWidth: 2))"
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Day one of this month.
    public var startOfMonth: CalendarDate {
        CalendarDate(validatedYear: year, month: month, day: 1)
    }

    /// The last day of this month, however many it has.
    public var endOfMonth: CalendarDate {
        CalendarDate(
            validatedYear: year,
            month: month,
            day: Self.daysInMonth(month, ofYear: year)
        )
    }

    /// The same day one month over, clamped to the length of the month it lands in: 31 January
    /// going forward is 28 February, not 3 March.
    ///
    /// `nil` only at the two ends of the supported range, which no ledger reaches.
    public func addingMonths(_ count: Int) -> CalendarDate? {
        let zeroBased = (year * 12 + month - 1) + count
        let targetYear = zeroBased / 12
        let targetMonth = zeroBased % 12 + 1
        guard (1...9999).contains(targetYear) else { return nil }
        return CalendarDate(
            validatedYear: targetYear,
            month: targetMonth,
            day: min(day, Self.daysInMonth(targetMonth, ofYear: targetYear))
        )
    }

    /// For the derivations above, where the year, month and day are already known to be valid
    /// and a `try` would only add noise a caller cannot act on.
    init(validatedYear year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    static func daysInMonth(_ month: Int, ofYear year: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: 31
        case 4, 6, 9, 11: 30
        case 2: isLeapYear(year) ? 29 : 28
        default: 0
        }
    }

    /// Full Gregorian rule: 2000 was a leap year, 1900 was not.
    static func isLeapYear(_ year: Int) -> Bool {
        if year % 400 == 0 { return true }
        if year % 100 == 0 { return false }
        return year % 4 == 0
    }

    private static func padded(_ number: Int, toWidth width: Int) -> String {
        let digits = String(number)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}

public enum CalendarDateError: Error, Equatable {
    case yearOutOfRange(Int)
    case monthOutOfRange(Int)
    case dayOutOfRange(Int, month: Int, year: Int)
    case malformedText(String)
}
