import Foundation

struct AlAdhanEnvelope<Value: Decodable>: Decodable {
    let code: Int?
    let status: String?
    let data: Value
}

struct AlAdhanDayDTO: Codable, Sendable {
    let timings: AlAdhanTimingsDTO
    let date: AlAdhanDateDTO
    let meta: AlAdhanMetaDTO?
}

struct AlAdhanTimingsDTO: Codable, Sendable {
    let imsak: String
    let fajr: String
    let sunrise: String
    let dhuhr: String
    let asr: String
    let sunset: String
    let maghrib: String
    let isha: String

    enum CodingKeys: String, CodingKey {
        case imsak = "Imsak"
        case fajr = "Fajr"
        case sunrise = "Sunrise"
        case dhuhr = "Dhuhr"
        case asr = "Asr"
        case sunset = "Sunset"
        case maghrib = "Maghrib"
        case isha = "Isha"
    }
}

struct AlAdhanDateDTO: Codable, Sendable {
    let hijri: AlAdhanHijriDTO
    let gregorian: AlAdhanGregorianDTO
}

struct AlAdhanHijriDTO: Codable, Sendable {
    let date: String
    let day: String
    let month: AlAdhanMonthDTO
    let year: String?
}

struct AlAdhanGregorianDTO: Codable, Sendable {
    let date: String
    let day: String
    let weekday: AlAdhanWeekdayDTO
    let month: AlAdhanMonthDTO
    let year: String?
}

struct AlAdhanMonthDTO: Codable, Sendable {
    let number: Int?
    let en: String
}

struct AlAdhanWeekdayDTO: Codable, Sendable {
    let en: String
}

struct AlAdhanMetaDTO: Codable, Sendable {
    let timezone: String?
    let method: AlAdhanMethodDTO?
}

struct AlAdhanMethodDTO: Codable, Sendable {
    let id: Int?
    let name: String?
}

protocol PrayerAPIClient: Sendable {
    func fetchDay(query: PrayerTimesQuery) async throws -> AlAdhanDayDTO
    func fetchMonth(day: LocalDay, location: PrayerLocation, settings: CalculationSettings) async throws -> [AlAdhanDayDTO]
}

final class AlAdhanAPIClient: PrayerAPIClient, @unchecked Sendable {
    private let session: URLSession
    private let baseURLString = "https://api.aladhan.com/v1"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchDay(query: PrayerTimesQuery) async throws -> AlAdhanDayDTO {
        let url = try makeURL(
            path: "timings/\(query.day.apiString)",
            latitude: query.latitude,
            longitude: query.longitude,
            method: query.method,
            madhab: query.madhab,
            hijriAdjustment: query.hijriAdjustment
        )
        let envelope: AlAdhanEnvelope<AlAdhanDayDTO> = try await request(url)
        return envelope.data
    }

    func fetchMonth(day: LocalDay, location: PrayerLocation, settings: CalculationSettings) async throws -> [AlAdhanDayDTO] {
        let url = try makeURL(
            path: "calendar/\(day.year)/\(day.month)",
            latitude: location.latitude,
            longitude: location.longitude,
            method: settings.method,
            madhab: settings.madhab,
            hijriAdjustment: settings.hijriAdjustment
        )
        let envelope: AlAdhanEnvelope<[AlAdhanDayDTO]> = try await request(url)
        return envelope.data
    }

    private func makeURL(
        path: String,
        latitude: Double,
        longitude: Double,
        method: CalculationMethod,
        madhab: Madhab,
        hijriAdjustment: Int
    ) throws -> URL {
        var components = URLComponents(string: "\(baseURLString)/\(path)")
        var items = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "school", value: String(madhab.apiSchool)),
            URLQueryItem(name: "adjustment", value: String(hijriAdjustment))
        ]
        if let methodID = method.apiID {
            items.append(URLQueryItem(name: "method", value: String(methodID)))
        }
        components?.queryItems = items
        guard let url = components?.url else { throw PrayerDataError.invalidURL }
        return url
    }

    private func request<Value: Decodable>(_ url: URL) async throws -> AlAdhanEnvelope<Value> {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw PrayerDataError.invalidData("Missing HTTP response")
            }
            guard (200...299).contains(http.statusCode) else {
                throw PrayerDataError.httpStatus(http.statusCode)
            }
            do {
                let envelope = try JSONDecoder().decode(AlAdhanEnvelope<Value>.self, from: data)
                if let code = envelope.code, !(200...299).contains(code) {
                    throw PrayerDataError.httpStatus(code)
                }
                return envelope
            } catch {
                throw PrayerDataError.decoding(error.localizedDescription)
            }
        } catch is CancellationError {
            throw PrayerDataError.cancelled
        } catch let error as PrayerDataError {
            throw error
        } catch {
            throw PrayerDataError.transport(error.localizedDescription)
        }
    }
}

enum PrayerDayMapper {
    static func map(
        _ dto: AlAdhanDayDTO,
        fallbackLocation: PrayerLocation,
        settings: CalculationSettings,
        nextSahri: Date? = nil,
        fetchedAt: Date = .now
    ) throws -> PrayerDay {
        guard let day = LocalDay(apiString: dto.date.gregorian.date) else {
            throw PrayerDataError.invalidData("Invalid Gregorian date")
        }
        let timeZoneID = dto.meta?.timezone ?? fallbackLocation.timeZoneIdentifier
        guard let timeZone = TimeZone(identifier: timeZoneID) else {
            throw PrayerDataError.invalidData("Invalid timezone")
        }

        func time(_ source: String, on localDay: LocalDay = day) throws -> Date {
            guard let pair = parseTime(source), let date = localDay.date(in: timeZone, hour: pair.hour, minute: pair.minute) else {
                throw PrayerDataError.invalidData("Invalid time: \(source)")
            }
            return date
        }

        let caution = TimeInterval(settings.cautionMinutes * 60)
        let imsak = try time(dto.timings.imsak)
        let fajr = try time(dto.timings.fajr)
        let sunrise = try time(dto.timings.sunrise)
        let dhuhr = try time(dto.timings.dhuhr)
        let asr = try time(dto.timings.asr)
        let sunset = try time(dto.timings.sunset)
        let maghrib = try time(dto.timings.maghrib).addingTimeInterval(caution)
        let isha = try time(dto.timings.isha)
        let sahri = imsak.addingTimeInterval(-caution)
        let iftar = sunset.addingTimeInterval(caution)
        let tomorrow = day.adding(days: 1, in: timeZone)
        let ishaEnd: Date
        if let nextSahri {
            ishaEnd = nextSahri
        } else {
            ishaEnd = try time(dto.timings.imsak, on: tomorrow).addingTimeInterval(-caution)
        }

        return PrayerDay(
            localDay: day,
            gregorianSummary: "\(dto.date.gregorian.weekday.en), \(dto.date.gregorian.day) \(dto.date.gregorian.month.en)",
            hijriSummary: "\(dto.date.hijri.day) \(dto.date.hijri.month.en) \(dto.date.hijri.year ?? "")".trimmingCharacters(in: .whitespaces),
            timeZoneIdentifier: timeZoneID,
            sunrise: sunrise,
            sunset: sunset,
            sahri: sahri,
            iftar: iftar,
            windows: [
                PrayerWindow(prayer: .fajr, start: fajr, end: sunrise),
                PrayerWindow(prayer: .dhuhr, start: dhuhr, end: asr),
                PrayerWindow(prayer: .asr, start: asr, end: sunset),
                PrayerWindow(prayer: .maghrib, start: maghrib, end: isha),
                PrayerWindow(prayer: .isha, start: isha, end: ishaEnd)
            ],
            methodName: dto.meta?.method?.name ?? settings.method.title,
            fetchedAt: fetchedAt
        )
    }

    private static func parseTime(_ value: String) -> (hour: Int, minute: Int)? {
        let pattern = #"\b([01]?\d|2[0-3]):([0-5]\d)\b"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let hourRange = Range(match.range(at: 1), in: value),
              let minuteRange = Range(match.range(at: 2), in: value),
              let hour = Int(value[hourRange]),
              let minute = Int(value[minuteRange]) else { return nil }
        return (hour, minute)
    }
}

private struct PrayerCacheEntry: Codable, Sendable {
    var query: PrayerTimesQuery
    var day: PrayerDay
    var storedAt: Date
}

private struct PrayerCacheFile: Codable {
    var entries: [String: PrayerCacheEntry]
}

actor PrayerTimesCache {
    struct Hit: Sendable {
        var day: PrayerDay
        var source: PrayerDataSource
        var isStale: Bool
    }

    private var memory: [String: PrayerCacheEntry] = [:]
    private var disk: [String: PrayerCacheEntry] = [:]
    private let fileURL: URL
    private let freshness: TimeInterval
    private let maxEntries = 760

    init(
        fileManager: FileManager = .default,
        fileURL overrideFileURL: URL? = nil,
        freshness: TimeInterval = 30 * 24 * 60 * 60
    ) {
        self.freshness = freshness
        if let overrideFileURL {
            fileURL = overrideFileURL
            if let data = try? Data(contentsOf: overrideFileURL),
               let decoded = try? JSONDecoder().decode(PrayerCacheFile.self, from: data) {
                disk = decoded.entries
            }
            return
        }
        let support = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        let directory = support.appending(path: "Salah", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(values)
        fileURL = directory.appending(path: "PrayerTimesCache-v2.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(PrayerCacheFile.self, from: data) {
            disk = decoded.entries
        }
    }

    func value(for query: PrayerTimesQuery, now: Date = .now) -> Hit? {
        if let entry = memory[query.cacheKey] {
            return Hit(day: entry.day, source: .memoryCache, isStale: now.timeIntervalSince(entry.storedAt) > freshness)
        }
        if let entry = disk[query.cacheKey] {
            memory[query.cacheKey] = entry
            return Hit(day: entry.day, source: .diskCache, isStale: now.timeIntervalSince(entry.storedAt) > freshness)
        }
        return nil
    }

    func store(_ day: PrayerDay, for query: PrayerTimesQuery, now: Date = .now) {
        let entry = PrayerCacheEntry(query: query, day: day, storedAt: now)
        memory[query.cacheKey] = entry
        disk[query.cacheKey] = entry
        prune()
        persist()
    }

    func invalidate(signature: String) {
        memory = memory.filter { $0.value.query.signature != signature }
        disk = disk.filter { $0.value.query.signature != signature }
        persist()
    }

    private func prune() {
        guard disk.count > maxEntries else { return }
        let retained = disk.values.sorted { $0.storedAt > $1.storedAt }.prefix(maxEntries)
        disk = Dictionary(uniqueKeysWithValues: retained.map { ($0.query.cacheKey, $0) })
        memory = memory.filter { disk[$0.key] != nil }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(PrayerCacheFile(entries: disk)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

actor DefaultPrayerTimesRepository: PrayerTimesRepository {
    private let client: any PrayerAPIClient
    private let cache: PrayerTimesCache
    private var inFlight: [String: Task<PrayerDay, Error>] = [:]
    private var inFlightMonths: [String: Task<[PrayerDay], Error>] = [:]

    init(client: any PrayerAPIClient, cache: PrayerTimesCache) {
        self.client = client
        self.cache = cache
    }

    func day(for query: PrayerTimesQuery, location: PrayerLocation, policy: CachePolicy) async throws -> LoadedPrayerDay {
        let cached = await cache.value(for: query)
        if policy == .cacheFirst, let cached, !cached.isStale {
            return LoadedPrayerDay(value: cached.day, source: cached.source, isStale: false)
        }

        do {
            let value = try await networkDay(for: query, location: location)
            return LoadedPrayerDay(value: value, source: .network, isStale: false)
        } catch {
            if let cached {
                return LoadedPrayerDay(value: cached.day, source: cached.source, isStale: true)
            }
            throw error
        }
    }

    func month(containing day: LocalDay, location: PrayerLocation, settings: CalculationSettings, policy: CachePolicy) async throws -> [LoadedPrayerDay] {
        let expectedDays = daysInMonth(containing: day, timeZone: location.timeZone)
        var cachedValues: [LoadedPrayerDay] = []
        for localDay in expectedDays {
            let query = PrayerTimesQuery(day: localDay, location: location, settings: settings)
            if let hit = await cache.value(for: query) {
                cachedValues.append(LoadedPrayerDay(value: hit.day, source: hit.source, isStale: hit.isStale))
            }
        }
        if policy == .cacheFirst, cachedValues.count == expectedDays.count, cachedValues.allSatisfy({ !$0.isStale }) {
            return cachedValues.sorted { $0.value.localDay < $1.value.localDay }
        }

        do {
            let prayerDays = try await networkMonth(containing: day, location: location, settings: settings)
            var loaded: [LoadedPrayerDay] = []
            for prayerDay in prayerDays {
                let query = PrayerTimesQuery(day: prayerDay.localDay, location: location, settings: settings)
                await cache.store(prayerDay, for: query)
                loaded.append(LoadedPrayerDay(value: prayerDay, source: .network, isStale: false))
            }
            return loaded.sorted { $0.value.localDay < $1.value.localDay }
        } catch {
            if !cachedValues.isEmpty {
                return cachedValues.map { LoadedPrayerDay(value: $0.value, source: $0.source, isStale: true) }
                    .sorted { $0.value.localDay < $1.value.localDay }
            }
            throw error
        }
    }

    func invalidate(signature: String) async {
        await cache.invalidate(signature: signature)
    }

    private func networkDay(for query: PrayerTimesQuery, location: PrayerLocation) async throws -> PrayerDay {
        if let task = inFlight[query.cacheKey] { return try await task.value }
        let client = self.client
        let cache = self.cache
        let task = Task<PrayerDay, Error> {
            let dto = try await client.fetchDay(query: query)
            let settings = CalculationSettings(
                method: query.method,
                madhab: query.madhab,
                hijriAdjustment: query.hijriAdjustment,
                cautionMinutes: query.cautionMinutes,
                timeFormat: .system
            )
            let nextDay = query.day.adding(days: 1, in: location.timeZone)
            let nextQuery = PrayerTimesQuery(day: nextDay, location: location, settings: settings)
            let nextPrayerDay: PrayerDay?
            if let hit = await cache.value(for: nextQuery), !hit.isStale {
                nextPrayerDay = hit.day
            } else if let nextDTO = try? await client.fetchDay(query: nextQuery) {
                nextPrayerDay = try? PrayerDayMapper.map(nextDTO, fallbackLocation: location, settings: settings)
                if let nextPrayerDay { await cache.store(nextPrayerDay, for: nextQuery) }
            } else {
                nextPrayerDay = nil
            }
            return try PrayerDayMapper.map(
                dto,
                fallbackLocation: location,
                settings: settings,
                nextSahri: nextPrayerDay?.sahri
            )
        }
        inFlight[query.cacheKey] = task
        defer { inFlight[query.cacheKey] = nil }
        let value = try await task.value
        await cache.store(value, for: query)
        return value
    }

    private func networkMonth(
        containing day: LocalDay,
        location: PrayerLocation,
        settings: CalculationSettings
    ) async throws -> [PrayerDay] {
        let key = "\(day.year)-\(day.month)|\(PrayerTimesQuery(day: day, location: location, settings: settings).signature)"
        if let task = inFlightMonths[key] { return try await task.value }
        let client = self.client
        let task = Task<[PrayerDay], Error> {
            let dtos = try await client.fetchMonth(day: day, location: location, settings: settings)
            var values = try dtos.map { try PrayerDayMapper.map($0, fallbackLocation: location, settings: settings) }
                .sorted { $0.localDay < $1.localDay }
            guard values.count > 1 else { return values }
            for index in values.indices.dropLast() {
                guard let ishaIndex = values[index].windows.firstIndex(where: { $0.prayer == .isha }) else { continue }
                values[index].windows[ishaIndex].end = values[index + 1].sahri
            }
            return values
        }
        inFlightMonths[key] = task
        defer { inFlightMonths[key] = nil }
        return try await task.value
    }

    private func daysInMonth(containing day: LocalDay, timeZone: TimeZone) -> [LocalDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let date = day.date(in: timeZone), let range = calendar.range(of: .day, in: .month, for: date) else { return [day] }
        return range.map { LocalDay(year: day.year, month: day.month, day: $0) }
    }
}
