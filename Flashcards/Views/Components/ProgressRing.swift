import SwiftUI

/// A small circular progress indicator.
struct ProgressRing: View {
    let progress: Double
    var tint: Color = .green
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeInOut, value: progress)
        .accessibilityElement()
        .accessibilityLabel("Mastered")
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

/// A labelled number used in statistics rows.
struct StatView: View {
    let value: Int
    let label: String
    var tint: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(value, format: .number)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A coloured badge showing a card's study status.
struct CardStatusBadge: View {
    let status: CardStatus

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: Capsule())
    }

    private var title: String {
        switch status {
        case .new: "New"
        case .learning: "Learning"
        case .mastered: "Mastered"
        }
    }

    private var tint: Color {
        switch status {
        case .new: .blue
        case .learning: .orange
        case .mastered: .green
        }
    }
}

extension Binding {
    /// A Bool binding that is true while `item` is non-nil; setting it to false clears the item.
    static func isPresent<Item>(_ item: Binding<Item?>) -> Binding<Bool> where Value == Bool {
        Binding<Bool>(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )
    }
}

#if DEBUG
#Preview("Progress Rings", traits: .sizeThatFitsLayout) {
    HStack(spacing: 24) {
        ProgressRing(progress: 0)
        ProgressRing(progress: 0.5, tint: .blue)
        ProgressRing(progress: 1)
    }
    .frame(height: 40)
    .padding()
}

#Preview("Statistics", traits: .sizeThatFitsLayout) {
    HStack {
        StatView(value: 2, label: "Chapters")
        StatView(value: 12, label: "Cards")
        StatView(value: 4, label: "Mastered", tint: .green)
    }
    .padding()
}

#Preview("Card Statuses", traits: .sizeThatFitsLayout) {
    HStack {
        CardStatusBadge(status: .new)
        CardStatusBadge(status: .learning)
        CardStatusBadge(status: .mastered)
    }
    .padding()
}
#endif
