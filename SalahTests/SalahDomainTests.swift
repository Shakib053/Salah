import SwiftData
import XCTest
@testable import Salah

final class SalahDomainTests: XCTestCase {
    private let zone = TimeZone(identifier: "Asia/Dhaka") ?? .gmt
    private let day = LocalDay(year: 2026, month: 7, day: 20)

    func testCurrentAndNextPrayerAcrossDay() throws {
        let today = try fixture(day: day)
        let yesterday = try fixture(day: day.adding(days: -1, in: zone))

        let beforeFajr = try XCTUnwrap(day.date(in: zone, hour: 4, minute: 30))
        let earlyMoment = PrayerTimeline.moment(now: beforeFajr, today: today, previous: yesterday)
        XCTAssertEqual(earlyMoment.current?.prayer, .isha)
        XCTAssertEqual(earlyMoment.next?.prayer, .fajr)

        let duringAsr = try XCTUnwrap(day.date(in: zone, hour: 16, minute: 30))
        let asrMoment = PrayerTimeline.moment(now: duringAsr, today: today, previous: yesterday)
        XCTAssertEqual(asrMoment.current?.prayer, .asr)
        XCTAssertEqual(asrMoment.next?.prayer, .maghrib)
        XCTAssertGreaterThan(asrMoment.progress, 0)

        let duringIsha = try XCTUnwrap(day.date(in: zone, hour: 23, minute: 0))
        XCTAssertEqual(PrayerTimeline.moment(now: duringIsha, today: today, previous: yesterday).current?.prayer, .isha)
    }

    func testPrayerWindowsUseExclusiveEndAndAccessibleDisplayEnd() throws {
        let value = try fixture(day: day).window(for: .fajr)
        let window = try XCTUnwrap(value)
        XCTAssertTrue(window.contains(window.start))
        XCTAssertFalse(window.contains(window.end))
        XCTAssertEqual(window.displayEnd, window.end.addingTimeInterval(-60))
    }

    func testIshaCrossesMidnightAndEndsAtAdjustedSahri() throws {
        let value = try fixture(day: day).window(for: .isha)
        let window = try XCTUnwrap(value)
        XCTAssertGreaterThan(window.end, try XCTUnwrap(day.adding(days: 1, in: zone).date(in: zone, hour: 0)))
        XCTAssertEqual(window.end, try XCTUnwrap(day.adding(days: 1, in: zone).date(in: zone, hour: 4, minute: 57)))
    }

    func testLocalCalculatorPreservesSahriAndIftarSafetyRules() throws {
        let calculator = AdhanPrayerTimesCalculator()
        let query = PrayerTimesQuery(day: day, location: .dhaka, settings: CalculationSettings())
        let calculated = try calculator.calculateDay(query: query, location: .dhaka)
        let fajr = try XCTUnwrap(calculated.window(for: .fajr)?.start)
        XCTAssertEqual(calculated.sahri, fajr.addingTimeInterval(-13 * 60))
        XCTAssertEqual(calculated.iftar, calculated.sunset.addingTimeInterval(3 * 60))
        XCTAssertEqual(calculated.window(for: .maghrib)?.start, calculated.iftar)
        XCTAssertEqual(calculated.methodName, CalculationMethod.karachi.fullTitle)
    }

    func testLocalCalculatorSupportsEveryDisplayedMethod() throws {
        let calculator = AdhanPrayerTimesCalculator()
        for method in CalculationMethod.allCases {
            var settings = CalculationSettings()
            settings.method = method
            let query = PrayerTimesQuery(day: day, location: .dhaka, settings: settings)
            let calculated = try calculator.calculateDay(query: query, location: .dhaka)
            XCTAssertEqual(calculated.windows.count, 5)
            XCTAssertLessThan(try XCTUnwrap(calculated.window(for: .fajr)?.start), calculated.sunrise)
            XCTAssertLessThan(calculated.sunrise, try XCTUnwrap(calculated.window(for: .dhuhr)?.start))
            XCTAssertGreaterThan(try XCTUnwrap(calculated.window(for: .isha)?.end), try XCTUnwrap(calculated.window(for: .isha)?.start))
        }
    }

    func testAutomaticMethodUsesBangladeshKarachiDefault() throws {
        var settings = CalculationSettings()
        settings.method = .automatic
        let query = PrayerTimesQuery(day: day, location: .dhaka, settings: settings)
        let calculated = try AdhanPrayerTimesCalculator().calculateDay(query: query, location: .dhaka)
        XCTAssertEqual(calculated.methodName, CalculationMethod.karachi.fullTitle)
    }

    func testHijriAdjustmentMovesDateLocally() throws {
        let calculator = AdhanPrayerTimesCalculator()
        var baseSettings = CalculationSettings()
        baseSettings.hijriAdjustment = 0
        var adjustedSettings = baseSettings
        adjustedSettings.hijriAdjustment = 1
        let base = try calculator.calculateDay(
            query: PrayerTimesQuery(day: day, location: .dhaka, settings: baseSettings),
            location: .dhaka
        )
        let adjusted = try calculator.calculateDay(
            query: PrayerTimesQuery(day: day, location: .dhaka, settings: adjustedSettings),
            location: .dhaka
        )
        XCTAssertNotEqual(base.hijriSummary, adjusted.hijriSummary)
    }

    func testCacheKeyIncludesEveryTimingInput() {
        let base = PrayerTimesQuery(day: day, location: .dhaka, settings: .init())
        var location = PrayerLocation.dhaka
        location.latitude += 0.001
        XCTAssertNotEqual(base.cacheKey, PrayerTimesQuery(day: day, location: location, settings: .init()).cacheKey)

        var settings = CalculationSettings()
        settings.method = .isna
        XCTAssertNotEqual(base.cacheKey, PrayerTimesQuery(day: day, location: .dhaka, settings: settings).cacheKey)
        settings = CalculationSettings(); settings.madhab = .standard
        XCTAssertNotEqual(base.cacheKey, PrayerTimesQuery(day: day, location: .dhaka, settings: settings).cacheKey)
        settings = CalculationSettings(); settings.hijriAdjustment = 1
        XCTAssertNotEqual(base.cacheKey, PrayerTimesQuery(day: day, location: .dhaka, settings: settings).cacheKey)
        settings = CalculationSettings(); settings.cautionMinutes = 5
        XCTAssertNotEqual(base.cacheKey, PrayerTimesQuery(day: day, location: .dhaka, settings: settings).cacheKey)
    }

    func testCacheFreshnessAndInvalidation() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = PrayerTimesCache(fileURL: file, freshness: 10)
        let query = PrayerTimesQuery(day: day, location: .dhaka, settings: .init())
        let value = try fixture(day: day)
        await cache.store(value, for: query, now: Date(timeIntervalSince1970: 100))
        let fresh = await cache.value(for: query, now: Date(timeIntervalSince1970: 105))
        let stale = await cache.value(for: query, now: Date(timeIntervalSince1970: 111))
        XCTAssertEqual(fresh?.isStale, false)
        XCTAssertEqual(stale?.isStale, true)
        await cache.invalidate(signature: query.signature)
        let invalidated = await cache.value(for: query)
        XCTAssertNil(invalidated)
    }

    func testLocalRepositoryCalculatesACompleteMonthWithoutNetwork() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let repository = DefaultPrayerTimesRepository(
            calculator: AdhanPrayerTimesCalculator(),
            cache: PrayerTimesCache(fileURL: file)
        )
        let values = try await repository.month(
            containing: day,
            location: .dhaka,
            settings: .init(),
            policy: .reload
        )
        XCTAssertEqual(values.count, 31)
        XCTAssertTrue(values.allSatisfy { $0.source == .calculated && !$0.isStale })
    }

    @MainActor
    func testSwiftDataRepositoryPreventsDuplicatePrayerDateRecords() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PrayerRecord.self, configurations: configuration)
        let repository = SwiftDataPrayerTrackingRepository(container: container)
        try repository.setCompleted(true, prayer: .fajr, day: day, timeZone: zone, source: "test")
        try repository.setCompleted(true, prayer: .fajr, day: day, timeZone: zone, source: "test")
        XCTAssertEqual(try repository.records(on: day).count, 1)
        try repository.setCompleted(false, prayer: .fajr, day: day, timeZone: zone, source: "undo")
        XCTAssertEqual(try repository.records(on: day).first?.completed, false)
    }

    func testStreakAndFirstTrackingDateDenominator() {
        let prior = day.adding(days: -1, in: zone)
        let records = [prior, day].flatMap { date in
            PrayerType.allCases.map { prayer in
                PrayerRecordSnapshot(id: UUID(), prayer: prayer, localDay: date, completed: true, completedAt: .now, source: "test", notes: nil)
            }
        }
        let result = TrackerInsightCalculator.calculate(records: records, today: day, timeZone: zone)
        XCTAssertEqual(result.currentStreak, 2)
        XCTAssertEqual(result.bestStreak, 2)
        XCTAssertEqual(result.possible, 10)
        XCTAssertEqual(result.completionPercentage, 1)
    }

    func testReminderIdentifiersOffsetsOrderingCapAndDuplicatePrevention() throws {
        let first = try fixture(day: day)
        let second = try fixture(day: day.adding(days: 1, in: zone))
        let preferences = Dictionary(uniqueKeysWithValues: PrayerEvent.allCases.map {
            ($0, ReminderPreference(enabled: true, offsetMinutes: 10))
        })
        let now = try XCTUnwrap(day.date(in: zone, hour: 0))
        let plan = ReminderPlan.make(days: [first, first, second], preferences: preferences, now: now, limit: 10)
        XCTAssertEqual(plan.count, 7)
        XCTAssertEqual(Set(plan.map(\.identifier)).count, plan.count)
        XCTAssertEqual(plan, plan.sorted { $0.triggerDate < $1.triggerDate })
        XCTAssertEqual(plan.first?.identifier, "salah.reminder.sahri.2026-07-20")
        XCTAssertEqual(plan.first?.triggerDate, first.sahri.addingTimeInterval(-600))
    }

    func testQiblaGeometryFromDhaka() {
        let bearing = QiblaGeometry.bearing(from: .dhaka)
        let distance = QiblaGeometry.distance(from: .dhaka).value
        XCTAssertTrue(275...280 ~= bearing)
        XCTAssertTrue(5_000...5_500 ~= distance)
        XCTAssertEqual(QiblaGeometry.shortestAngle(350), -10, accuracy: 0.001)
    }

    func testNearestDistrictUsesCoordinateDistance() throws {
        let districts = [
            District(id: "dhaka", name: "Dhaka", banglaName: "ঢাকা", latitude: 23.7115, longitude: 90.4111),
            District(id: "chattogram", name: "Chattogram", banglaName: "চট্টগ্রাম", latitude: 22.3569, longitude: 91.7832)
        ]
        let nearest = DistrictLoader.nearest(
            to: .init(latitude: 22.34, longitude: 91.82),
            districts: districts
        )
        XCTAssertEqual(try XCTUnwrap(nearest).name, "Chattogram")
    }

    private func fixture(day: LocalDay) throws -> PrayerDay {
        func date(_ hour: Int, _ minute: Int) throws -> Date {
            try XCTUnwrap(day.date(in: zone, hour: hour, minute: minute))
        }
        let tomorrow = day.adding(days: 1, in: zone)
        return PrayerDay(
            localDay: day,
            gregorianSummary: "Monday, 20 July",
            hijriSummary: "5 Safar 1448",
            timeZoneIdentifier: zone.identifier,
            sunrise: try date(6, 15),
            sunset: try date(18, 30),
            sahri: try date(4, 57),
            iftar: try date(18, 33),
            windows: [
                PrayerWindow(prayer: .fajr, start: try date(5, 5), end: try date(6, 15)),
                PrayerWindow(prayer: .dhuhr, start: try date(12, 10), end: try date(16, 0)),
                PrayerWindow(prayer: .asr, start: try date(16, 0), end: try date(18, 30)),
                PrayerWindow(prayer: .maghrib, start: try date(18, 33), end: try date(20, 0)),
                PrayerWindow(
                    prayer: .isha,
                    start: try date(20, 0),
                    end: try XCTUnwrap(tomorrow.date(in: zone, hour: 4, minute: 57))
                )
            ],
            methodName: CalculationMethod.karachi.fullTitle,
            fetchedAt: .now
        )
    }
}
