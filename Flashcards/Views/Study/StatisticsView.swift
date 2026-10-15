import Charts
import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Query private var cards: [Flashcard]
    @Query(sort: \ReviewRecord.reviewedAt) private var reviews: [ReviewRecord]

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                let now = Date.now
                let metrics = StudyMetrics(reviews: reviews)
                let days = (0..<7).reversed().compactMap {
                    Calendar.current.date(byAdding: .day, value: -$0, to: now)
                }
                List {
                    Section("Your Library") {
                        LabeledContent("Cards", value: cards.count, format: .number)
                        LabeledContent("Due now", value: cards.filter { $0.isDue(at: now) }.count, format: .number)
                        LabeledContent("Mastered", value: cards.filter(\.isMastered).count, format: .number)
                        LabeledContent("Favourites", value: cards.filter(\.isFavorite).count, format: .number)
                    }
                    Section("Study Activity") {
                        LabeledContent("Reviews today", value: metrics.count(on: now), format: .number)
                        LabeledContent("Current streak", value: "\(metrics.streak(at: now)) day(s)")
                        LabeledContent("Recorded reviews", value: reviews.count, format: .number)
                        LabeledContent("Accuracy", value: reviews.isEmpty ? "—" : metrics.accuracy.formatted(.percent.precision(.fractionLength(0))))
                    }
                    Section {
                        Chart(days, id: \.self) { day in
                            BarMark(
                                x: .value("Day", day, unit: .day),
                                y: .value("Reviews", metrics.count(on: day))
                            )
                            .foregroundStyle(.blue.gradient)
                            .accessibilityLabel(day.formatted(date: .abbreviated, time: .omitted))
                            .accessibilityValue("\(metrics.count(on: day)) reviews")
                        }
                        .frame(height: 200)
                    } header: {
                        Text("Last 7 Days")
                    } footer: {
                        Text("Activity starts with reviews recorded in this version. Imported review history is included. Deleting cards also removes their activity.")
                    }
                }
            }
            .navigationTitle("Statistics")
        }
    }
}

#if DEBUG
#Preview("Statistics") {
    let data = PreviewData()
    return StatisticsView().modelContainer(data.container)
}
#endif
