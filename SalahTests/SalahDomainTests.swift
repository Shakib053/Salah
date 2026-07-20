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

    func testMapperParsesTimezoneSuffixAndAppliesCautionOnce() throws {
        let dto = makeDTO(day: day, imsak: "05:00 (+06)", maghrib: "18:30 (BDT)")
        let mapped = try PrayerDayMapper.map(dto, fallbackLocation: .dhaka, settings: CalculationSettings())
        XCTAssertEqual(mapped.sahri, try XCTUnwrap(day.date(in: zone, hour: 4, minute: 57)))
        XCTAssertEqual(mapped.iftar, try XCTUnwrap(day.date(in: zone, hour: 18, minute: 33)))
        XCTAssertEqual(mapped.window(for: .maghrib)?.start, mapped.iftar)
    }

    func testInvalidAPIDateAndTimeAreRejected() {
        var dto = makeDTO(day: day)
        dto = AlAdhanDayDTO(timings: AlAdhanTimingsDTO(
            imsak: "invalid", fajr: dto.timings.fajr, sunrise: dto.timings.sunrise,
            dhuhr: dto.timings.dhuhr, asr: dto.timings.asr, sunset: dto.timings.sunset,
            maghrib: dto.timings.maghrib, isha: dto.timings.isha
        ), date: dto.date, meta: dto.meta)
        XCTAssertThrowsError(try PrayerDayMapper.map(dto, fallbackLocation: .dhaka, settings: .init()))
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

    private func fixture(day: LocalDay) throws -> PrayerDay {
        try PrayerDayMapper.map(makeDTO(day: day), fallbackLocation: .dhaka, settings: .init())
    }

    private func makeDTO(day: LocalDay, imsak: String = "05:00 (+06)", maghrib: String = "18:30 (+06)") -> AlAdhanDayDTO {
        AlAdhanDayDTO(
            timings: AlAdhanTimingsDTO(
                imsak: imsak, fajr: "05:05 (+06)", sunrise: "06:15 (+06)", dhuhr: "12:10 (+06)",
                asr: "16:00 (+06)", sunset: "18:30 (+06)", maghrib: maghrib, isha: "20:00 (+06)"
            ),
            date: AlAdhanDateDTO(
                hijri: AlAdhanHijriDTO(date: "05-02-1448", day: "5", month: .init(number: 2, en: "Safar"), year: "1448"),
                gregorian: AlAdhanGregorianDTO(date: day.apiString, day: String(day.day), weekday: .init(en: "Monday"), month: .init(number: day.month, en: "July"), year: String(day.year))
            ),
            meta: AlAdhanMetaDTO(timezone: zone.identifier, method: .init(id: 1, name: "University of Islamic Sciences, Karachi"))
        )
    }
}
