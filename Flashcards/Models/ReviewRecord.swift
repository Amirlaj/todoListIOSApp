import Foundation
import SwiftData

@Model
final class ReviewRecord {
    var reviewedAt: Date = Date.now
    var wasCorrect: Bool = false
    var card: Flashcard?

    init(reviewedAt: Date = .now, wasCorrect: Bool) {
        self.reviewedAt = reviewedAt
        self.wasCorrect = wasCorrect
    }
}

enum ReviewSchedule {
    /// Missed cards return in ten minutes; known cards expand to 1, 3, 7, 14, then 30 days.
    static func nextDate(box: Int, after date: Date) -> Date {
        let intervals: [TimeInterval] = [600, 86_400, 259_200, 604_800, 1_209_600, 2_592_000]
        return date.addingTimeInterval(intervals[max(0, min(box, intervals.count - 1))])
    }
}

enum CardTags {
    static func parse(_ text: String) -> [String] {
        var seen = Set<String>()
        return text.split(separator: ",").map { String($0).trimmed.lowercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

struct StudyMetrics {
    let reviews: [ReviewRecord]

    var accuracy: Double {
        reviews.isEmpty ? 0 : Double(reviews.filter(\.wasCorrect).count) / Double(reviews.count)
    }

    func count(on day: Date, calendar: Calendar = .current) -> Int {
        reviews.filter { calendar.isDate($0.reviewedAt, inSameDayAs: day) }.count
    }

    func streak(at now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(reviews.filter { $0.reviewedAt <= now }.map { calendar.startOfDay(for: $0.reviewedAt) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
