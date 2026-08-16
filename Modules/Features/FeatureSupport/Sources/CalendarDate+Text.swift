import Foundation
import KeepworthDomain

extension CalendarDate {
    /// The date as the reader's language writes it.
    ///
    /// Rendered **at noon UTC**. A `CalendarDate` has no time zone, so any other hour could
    /// land on the day before or after depending on where it is read — which is precisely the
    /// bug the type exists to prevent, and it would be careless to reintroduce it on the last
    /// step to the screen.
    ///
    /// Falls back to `yyyy-MM-dd` if the instant cannot be built, which a Gregorian calendar
    /// and a validated date do not allow.
    public func formatted(_ style: Date.FormatStyle) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let instant = calendar.date(from: components) else { return description }
        return instant.formatted(style)
    }

    /// "16 January 2026" in English, "16 de enero de 2026" in Spanish.
    public static func longDayStyle(in locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle.dateTime.day().month(.wide).year().locale(locale)
    }
}
