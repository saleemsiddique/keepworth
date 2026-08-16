import Foundation

extension CalendarDate {
    /// The day an instant falls on, in a given calendar.
    ///
    /// **This is the one place a time zone enters the domain**, and it is why the calendar is
    /// a parameter rather than `Calendar.current` read from inside: a screen asks what today
    /// is where the user is standing, and from then on the answer is frozen and never
    /// reinterpreted. A movement dated here keeps its day when it syncs to a device six hours
    /// away, which is what stops two devices from showing different monthly reports.
    public init(_ instant: Date, in calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        // A Gregorian calendar always yields all three, and every combination it yields is a
        // real date. Falling back to the epoch is unreachable, and beats making every screen
        // handle an impossible failure.
        guard let year = parts.year, let month = parts.month, let day = parts.day,
            let date = try? CalendarDate(year: year, month: month, day: day)
        else {
            self.init(validatedYear: 1970, month: 1, day: 1)
            return
        }
        self = date
    }
}
