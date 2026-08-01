//
//  DebugDrawerView.swift
//  Salah
//
//  Created by Kazi Tanjim Shakib on 31/7/26.
//

import Foundation
import SwiftUI

// MARK: - Debug Drawer (DEBUG builds only)

#if DEBUG
@MainActor
struct DebugDrawerView: View {
    @Bindable var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.salahPalette) private var palette

    // Mirror the same AppStorage keys used by TrackerView in TrackerHistory.swift.
    @AppStorage("salah.deeds.istighfar-count") private var tasbihCount = 0
    @AppStorage("salah.deeds.tasbih-goal") private var tasbihGoal = 0
    @AppStorage("salah.deeds.good-deeds-mask") private var goodDeedsMask = 0
    @AppStorage("salah.deeds.good-deeds-day")  private var goodDeedsDay = ""
    @AppStorage("salah.deeds.charity-total")   private var charityTotal = 0
    @AppStorage("salah.deeds.charity-goal")    private var charityGoal = 100
    @AppStorage("salah.deeds.charity-month")   private var charityMonth = ""
    @AppStorage(CharityLedger.storageKey)       private var charityEntriesData = Data()

    @State private var seedMessage: String?
    @State private var deleteMessage: String?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(
                        "Debug tools are only compiled in DEBUG builds and are never present in App Store releases.",
                        systemImage: "hammer.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("Tracker Tab") {
                    Button {
                        seedDummyData()
                    } label: {
                        Label("Add 30 Days of Dummy Data", systemImage: "wand.and.stars")
                    }
                    .foregroundStyle(palette.accent)

                    if let seedMessage {
                        Label(seedMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.footnote)
                    }
                }

                Section("Reset") {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete All Dummy Data", systemImage: "trash.fill")
                    }

                    if let deleteMessage {
                        Label(deleteMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Debug Drawer 🛠️")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Delete All Dummy Data?",
                isPresented: $showingDeleteConfirmation
            ) {
                Button("Delete", role: .destructive) {
                    deleteDummyData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This resets all Tracker tab data: prayer records, Tasbih counter, Good Deeds, and Charity.")
            }
        }
    }

    // MARK: Seed logic

    private func seedDummyData() {
        let timeZone = container.settings.location.timeZone
        let today = LocalDay(.now, timeZone: timeZone)

        // ── Ṣalāh: 30 past days, 3–5 random prayers completed each day ──
        let prayers = PrayerType.allCases
        for offset in 1...30 {
            let day = today.adding(days: -offset, in: timeZone)
            let doneCount = Int.random(in: 3...5)
            let shuffled = prayers.shuffled().prefix(doneCount)
            for prayer in shuffled {
                try? container.trackingRepository.setCompleted(
                    true, prayer: prayer,
                    day: day, timeZone: timeZone,
                    source: "debug"
                )
            }
        }

        // ── Tasbih: set counter to a random value 40–99 ──
        tasbihCount = Int.random(in: 40...99)
        tasbihGoal = 100

        // ── Good Deeds: mark all 3 deeds as done for today ──
        //    Bits 0, 1, 2 map to the three GoodDeedDefinitions in TrackerView
        goodDeedsDay = today.key
        goodDeedsMask = 0b111

        // ── Charity: plausible amount for the current month ──
        let components = Calendar.current.dateComponents([.year, .month], from: .now)
        charityMonth = String(format: "%04d-%02d", components.year ?? 1970, components.month ?? 1)
        charityGoal = 100
        let amounts = [15, 20, 25]
        let entries = amounts.enumerated().map { index, amount in
            CharityEntry(
                amount: Double(amount),
                date: Calendar.current.date(byAdding: .day, value: -(index * 4), to: .now) ?? .now,
                category: CharityCategory.allCases[index],
                recipient: ["Local food bank", "Education fund", "Emergency appeal"][index]
            )
        }
        charityEntriesData = CharityLedger.encode(entries)
        charityTotal = amounts.reduce(0, +)

        seedMessage = "Dummy data seeded for all Deeds sections ✓"
        deleteMessage = nil   // clear any prior delete confirmation
    }

    // MARK: Delete logic

    private func deleteDummyData() {
        // ── Prayer records: wipe all SwiftData tracker records ──
        try? container.trackingRepository.clearAll()

        // ── Tasbih ──
        tasbihCount = 0
        tasbihGoal = 0

        // ── Good Deeds ──
        goodDeedsMask = 0
        goodDeedsDay = ""

        // ── Charity ──
        charityTotal = 0
        charityGoal = 100
        charityMonth = ""
        charityEntriesData = Data()

        deleteMessage = "All dummy data deleted ✓"
        seedMessage = nil   // clear any prior seed confirmation
    }
}
#endif
