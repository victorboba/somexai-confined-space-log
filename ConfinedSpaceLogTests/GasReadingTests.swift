import Testing
import Foundation
@testable import ConfinedSpaceLog

@MainActor
struct GasReadingTests {
    @Test func aReadingWithNoValuesHasNoValue() {
        #expect(!GasReading(kind: .preEntry).hasAnyValue)
    }

    @Test func aReadingWithOnlyOneGasSetHasAValue() {
        let reading = GasReading(kind: .preEntry)
        reading.oxygenPercent = 20.9
        #expect(reading.hasAnyValue)
    }

    @Test func aZeroReadingCountsAsAValueNotAsBlank() {
        // 0 LEL is a real, meaningful reading — it must not be confused with "not measured".
        let reading = GasReading(kind: .preEntry)
        reading.lelPercent = 0
        #expect(reading.hasAnyValue)
        #expect(reading.value(for: .lel) == 0)
    }

    @Test func valueAndSetValueRoundTripForEveryGas() {
        let reading = GasReading(kind: .preEntry)
        for gas in Gas.allCases {
            reading.setValue(42, for: gas)
            #expect(reading.value(for: gas) == 42)
        }
    }

    @Test func ageDescribesJustNowUnderAMinute() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reading = GasReading(takenAt: now.addingTimeInterval(-10), kind: .preEntry)
        #expect(reading.age(asOf: now) == "just now")
    }

    @Test func ageDescribesMinutesUnderAnHour() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reading = GasReading(takenAt: now.addingTimeInterval(-25 * 60), kind: .preEntry)
        #expect(reading.age(asOf: now) == "25 min ago")
    }

    @Test func ageDescribesHoursAndMinutesUnderADay() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reading = GasReading(takenAt: now.addingTimeInterval(-(2 * 3600 + 5 * 60)), kind: .preEntry)
        #expect(reading.age(asOf: now) == "2 hr 5 min ago")
    }

    @Test func ageDescribesWholeDaysAtADayOrMore() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reading = GasReading(takenAt: now.addingTimeInterval(-2 * 86400), kind: .preEntry)
        #expect(reading.age(asOf: now) == "2 days ago")
    }
}

struct GasFormattingTests {
    @Test func wholeNumbersPrintWithoutADecimalPoint() {
        #expect(Gas.format(21) == "21")
    }

    @Test func fractionalValuesPrintToOneDecimalPlace() {
        #expect(Gas.format(20.9) == "20.9")
    }

    @Test func aMissingValueFormatsAsAnEmDash() {
        #expect(Gas.oxygen.formatted(nil) == "—")
    }

    @Test func aValueFormatsWithItsUnit() {
        #expect(Gas.oxygen.formatted(20.9) == "20.9 %")
        #expect(Gas.carbonMonoxide.formatted(5) == "5 ppm")
    }

    @Test func theStandardFourExcludeOther() {
        #expect(!Gas.standard.contains(.other))
        #expect(Gas.standard.count == 4)
    }
}
