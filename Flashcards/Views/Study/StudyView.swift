import SwiftData
import SwiftUI

/// The cards to study and a title for the session.
struct StudySession: Identifiable {
    let id = UUID()
    let title: String
    let cards: [Flashcard]
}

/// Shows cards one at a time. Tap to flip; swipe right (or "Got It") if you knew the answer,
/// swipe left (or "Again") if you didn't. Missed cards can be reviewed again at the end.
struct StudyView: View {
    let session: StudySession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("study.shuffle") private var shuffle = true
    @AppStorage("study.backFirst") private var showBackFirst = false

    @State private var queue: [Flashcard] = []
    @State private var index = 0
    @State private var isRevealed = false
    @State private var knownCount = 0
    @State private var missed: [Flashcard] = []
    @State private var dragOffset: CGSize = .zero
    @State private var isAdvancing = false
    @State private var hasStarted = false

    private let swipeThreshold: CGFloat = 110

    private var currentCard: Flashcard? {
        queue.indices.contains(index) ? queue[index] : nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if let card = currentCard {
                    studyContent(for: card)
                } else if hasStarted {
                    summary
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        CardStore.save(modelContext)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    optionsMenu
                }
            }
        }
        .onAppear {
            guard !hasStarted else { return }
            start(with: session.cards)
            hasStarted = true
        }
    }

    // MARK: - Studying

    private func studyContent(for card: Flashcard) -> some View {
        VStack(spacing: 18) {
            progressHeader

            FlipCardView(
                front: showBackFirst ? card.back : card.front,
                back: showBackFirst ? card.front : card.back,
                frontCaption: showBackFirst ? "Answer" : "Question",
                backCaption: showBackFirst ? "Question" : "Answer",
                isFlipped: isRevealed
            )
            .overlay(alignment: .top) { swipeFeedback }
            .offset(x: dragOffset.width, y: dragOffset.height * 0.2)
            .rotationEffect(.degrees(Double(dragOffset.width / 22)))
            .id(card.persistentModelID)
            .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .identity))
            .frame(maxWidth: 640)
            .onTapGesture(perform: flip)
            .gesture(dragGesture)

            controls
        }
        .padding()
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(index), total: Double(max(queue.count, 1)))
            HStack {
                Text("Card \(index + 1) of \(queue.count)")
                    .monospacedDigit()
                Spacer()
                Label("\(missed.count)", systemImage: "xmark")
                    .foregroundStyle(.red)
                Label("\(knownCount)", systemImage: "checkmark")
                    .foregroundStyle(.green)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 640)
    }

    @ViewBuilder
    private var swipeFeedback: some View {
        let progress = min(abs(dragOffset.width) / swipeThreshold, 1)
        if dragOffset.width != 0 {
            let knew = dragOffset.width > 0
            Text(knew ? "GOT IT" : "AGAIN")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(knew ? Color.green : Color.red, in: Capsule())
                .padding(.top, 16)
                .opacity(progress)
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            if isRevealed {
                HStack(spacing: 14) {
                    Button {
                        grade(knewIt: false)
                    } label: {
                        Label("Again", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .keyboardShortcut(.leftArrow, modifiers: [])

                    Button {
                        grade(knewIt: true)
                    } label: {
                        Label("Got It", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                }
            } else {
                Button(action: flip) {
                    Text("Show Answer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])
            }

            Text("Tap the card to flip it. Swipe right if you knew it, left if you didn’t.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .controlSize(.large)
        .frame(maxWidth: 640)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                guard !isAdvancing else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isAdvancing else { return }
                if abs(value.translation.width) > swipeThreshold {
                    grade(knewIt: value.translation.width > 0)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private var optionsMenu: some View {
        Menu {
            Toggle(isOn: $shuffle) {
                Label("Shuffle Cards", systemImage: "shuffle")
            }
            Toggle(isOn: $showBackFirst) {
                Label("Show Answer Side First", systemImage: "arrow.left.arrow.right")
            }
            Divider()
            Button {
                start(with: session.cards)
            } label: {
                Label("Restart Session", systemImage: "arrow.counterclockwise")
            }
        } label: {
            Label("Options", systemImage: "slider.horizontal.3")
        }
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: missed.isEmpty ? "star.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(missed.isEmpty ? Color.yellow : Color.green)

            VStack(spacing: 8) {
                Text(queue.isEmpty ? "No Cards to Study" : (missed.isEmpty ? "Perfect Round!" : "Round Complete"))
                    .font(.title.bold())
                if !queue.isEmpty {
                    Text("You knew \(knownCount) of \(queue.count) card(s).")
                        .foregroundStyle(.secondary)
                }
            }

            if !queue.isEmpty {
                HStack(spacing: 16) {
                    summaryTile(value: knownCount, label: "Knew", tint: .green)
                    summaryTile(value: missed.count, label: "Again", tint: .red)
                }
                .frame(maxWidth: 400)
            }

            Spacer()

            VStack(spacing: 12) {
                if !missed.isEmpty {
                    Button {
                        start(with: missed)
                    } label: {
                        Label("Review \(missed.count) Missed Card(s)", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                if !session.cards.isEmpty {
                    Button {
                        start(with: session.cards)
                    } label: {
                        Label("Study All Again", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                Button("Done") {
                    CardStore.save(modelContext)
                    dismiss()
                }
                .padding(.top, 4)
            }
            .controlSize(.large)
            .frame(maxWidth: 400)
        }
        .padding()
    }

    private func summaryTile(value: Int, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value, format: .number)
                .font(.largeTitle.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Actions

    private func start(with cards: [Flashcard]) {
        queue = shuffle ? cards.shuffled() : cards
        index = 0
        knownCount = 0
        missed = []
        isRevealed = false
        dragOffset = .zero
        isAdvancing = false
    }

    private func flip() {
        guard !isAdvancing, currentCard != nil else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            isRevealed.toggle()
        }
    }

    private func grade(knewIt: Bool) {
        guard !isAdvancing, let card = currentCard else { return }
        isAdvancing = true

        card.recordReview(correct: knewIt)
        if knewIt {
            knownCount += 1
        } else {
            missed.append(card)
        }

        let exitDistance: CGFloat = knewIt ? 700 : -700
        withAnimation(.easeIn(duration: 0.22)) {
            dragOffset = CGSize(width: exitDistance, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isRevealed = false
            dragOffset = .zero
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                index += 1
            }
            isAdvancing = false
            if index >= queue.count {
                CardStore.save(modelContext)
            }
        }
    }
}
