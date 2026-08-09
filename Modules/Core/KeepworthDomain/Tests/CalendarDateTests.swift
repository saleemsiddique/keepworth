import Testing

@testable import KeepworthDomain

@Test("Una fecha válida conserva sus tres componentes")
func keepsItsComponents() throws {
    let date = try CalendarDate(year: 2026, month: 1, day: 31)

    #expect(date.year == 2026)
    #expect(date.month == 1)
    #expect(date.day == 31)
}

@Test("Un mes fuera de rango se rechaza", arguments: [0, 13, -1])
func rejectsMonthOutOfRange(month: Int) {
    #expect(throws: CalendarDateError.monthOutOfRange(month)) {
        try CalendarDate(year: 2026, month: month, day: 1)
    }
}

@Test("Un día que ese mes no tiene se rechaza")
func rejectsDayThatMonthDoesNotHave() {
    #expect(throws: CalendarDateError.dayOutOfRange(31, month: 4, year: 2026)) {
        try CalendarDate(year: 2026, month: 4, day: 31)
    }
}

@Test("El 29 de febrero existe en año bisiesto")
func acceptsLeapDayInLeapYear() throws {
    #expect(try CalendarDate(year: 2024, month: 2, day: 29).day == 29)
}

@Test("El 29 de febrero no existe en año común")
func rejectsLeapDayInCommonYear() {
    #expect(throws: CalendarDateError.dayOutOfRange(29, month: 2, year: 2026)) {
        try CalendarDate(year: 2026, month: 2, day: 29)
    }
}

@Test("La regla gregoriana de años bisiestos se aplica entera")
func appliesFullGregorianLeapRule() {
    // 2000 es bisiesto por la regla del 400; 1900 no lo es por la del 100.
    #expect(CalendarDate.isLeapYear(2000))
    #expect(!CalendarDate.isLeapYear(1900))
    #expect(CalendarDate.isLeapYear(2024))
    #expect(!CalendarDate.isLeapYear(2026))
}

@Test("La forma textual es ISO 8601 con ceros a la izquierda")
func rendersAsIso8601() throws {
    #expect(try CalendarDate(year: 2026, month: 1, day: 5).description == "2026-01-05")
    #expect(try CalendarDate(year: 999, month: 12, day: 31).description == "0999-12-31")
}

@Test("Leer y escribir la forma ISO 8601 devuelve la misma fecha")
func roundTripsThroughIso8601() throws {
    let original = try CalendarDate(year: 2026, month: 2, day: 28)

    #expect(try CalendarDate(iso8601: original.description) == original)
}

@Test(
    "Un texto que no es yyyy-MM-dd se rechaza",
    arguments: ["2026-1-31", "31-01-2026", "2026/01/31", "2026-01", "", "hoy"]
)
func rejectsMalformedText(text: String) {
    #expect(throws: CalendarDateError.malformedText(text)) {
        try CalendarDate(iso8601: text)
    }
}

@Test("Un texto con forma correcta pero fecha imposible se rechaza")
func rejectsImpossibleDateInWellFormedText() {
    #expect(throws: CalendarDateError.dayOutOfRange(31, month: 2, year: 2026)) {
        try CalendarDate(iso8601: "2026-02-31")
    }
}

@Test("Las fechas se ordenan por año, mes y día")
func ordersChronologically() throws {
    let last = try CalendarDate(year: 2026, month: 1, day: 31)
    let first = try CalendarDate(year: 2025, month: 12, day: 31)
    let middle = try CalendarDate(year: 2026, month: 1, day: 1)

    #expect([last, first, middle].sorted() == [first, middle, last])
}

@Test("Ordenar por la forma textual da el mismo resultado que ordenar por fecha")
func textualOrderMatchesChronologicalOrder() throws {
    // Es lo que permite que la columna TEXT del esquema se ordene en SQL sin conversiones.
    let dates = try [
        CalendarDate(year: 2026, month: 10, day: 1),
        CalendarDate(year: 2026, month: 2, day: 9),
        CalendarDate(year: 2025, month: 12, day: 31),
    ]

    #expect(dates.sorted().map(\.description) == dates.map(\.description).sorted())
}
