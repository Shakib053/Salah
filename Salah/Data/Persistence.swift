import Foundation
import SwiftData

@Model
final class PrayerRecord {
    @Attribute(.unique) var uniquenessKey: String
    var id: UUID
    var prayerRawValue: String
    var localDateKey: String
    var timeZoneIdentifier: String
    var isCompleted: Bool
    var completedAt: Date?
    var completionSource: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        prayer: PrayerType,
        localDay: LocalDay,
        timeZoneIdentifier: String,
        isCompleted: Bool,
        completedAt: Date?,
        completionSource: String?,
        notes: String? = nil
    ) {
        uniquenessKey = "\(localDay.key)|\(prayer.rawValue)"
        self.id = id
        prayerRawValue = prayer.rawValue
        localDateKey = localDay.key
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.completionSource = completionSource
        self.notes = notes
        createdAt = .now
        updatedAt = .now
    }

    var snapshot: PrayerRecordSnapshot? {
        guard let prayer = PrayerType(rawValue: prayerRawValue),
              let day = LocalDay(stableKey: localDateKey) else { return nil }
        return PrayerRecordSnapshot(
            id: id,
            prayer: prayer,
            localDay: day,
            completed: isCompleted,
            completedAt: completedAt,
            source: completionSource,
            notes: notes
        )
    }
}

extension LocalDay {
    init?(stableKey: String) {
        let parts = stableKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }
}

@MainActor
final class SwiftDataPrayerTrackingRepository: PrayerTrackingRepository {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
        context.autosaveEnabled = true
    }

    func records(on day: LocalDay) throws -> [PrayerRecordSnapshot] {
        let key = day.key
        let descriptor = FetchDescriptor<PrayerRecord>(
            predicate: #Predicate { $0.localDateKey == key },
            sortBy: [SortDescriptor(\.prayerRawValue)]
        )
        return try context.fetch(descriptor).compactMap(\.snapshot)
    }

    func completedPrayerTypes(on day: LocalDay) throws -> Set<PrayerType> {
        Set(try records(on: day).filter(\.completed).map(\.prayer))
    }

    func setCompleted(_ completed: Bool, prayer: PrayerType, day: LocalDay, timeZone: TimeZone, source: String) throws {
        let uniqueKey = "\(day.key)|\(prayer.rawValue)"
        let descriptor = FetchDescriptor<PrayerRecord>(predicate: #Predicate { $0.uniquenessKey == uniqueKey })
        if let existing = try context.fetch(descriptor).first {
            existing.isCompleted = completed
            existing.completedAt = completed ? .now : nil
            existing.completionSource = source
            existing.updatedAt = .now
        } else {
            context.insert(PrayerRecord(
                prayer: prayer,
                localDay: day,
                timeZoneIdentifier: timeZone.identifier,
                isCompleted: completed,
                completedAt: completed ? .now : nil,
                completionSource: source
            ))
        }
        try context.save()
    }

    func allRecords() throws -> [PrayerRecordSnapshot] {
        let descriptor = FetchDescriptor<PrayerRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try context.fetch(descriptor).compactMap(\.snapshot)
    }

    func clearAll() throws {
        try context.delete(model: PrayerRecord.self)
        try context.save()
    }
}
