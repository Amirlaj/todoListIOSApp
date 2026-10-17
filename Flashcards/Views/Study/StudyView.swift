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
    @State private var saveError: String?
    @State private var advanceTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let swipeThreshold: CGFloat = 80

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
        .onDisappear { advanceTask?.cancel() }
        .alert("Review Not Saved", isPresented: .isPresent($saveError)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
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
            .simultaneousGesture(dragGesture)
            .accessibilityIdentifier("study-card")
            .accessibilityAction(named: "Reject card") { grade(knewIt: false) }
            .accessibilityAction(named: "Accept card") { grade(knewIt: true) }

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
            Label(knew ? "ACCEPTED" : "REJECTED", systemImage: knew ? "checkmark" : "xmark")
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

            Text("Swipe left to reject, right to accept. Tap to flip the card at any time.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .controlSize(.large)
        .frame(maxWidth: 640)
        .disabled(isAdvancing)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                guard !isAdvancing,
                      abs(value.translation.width) > abs(value.translation.height) else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isAdvancing else { return }
                if abs(value.translation.width) >= swipeThreshold,
                   abs(value.translation.width) > abs(value.translation.height) * 1.2 {
                    grade(knewIt: value.translation.width > 0)
                } else {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private var optionsMenu: some View {
        Menu {
            if let card = currentCard {
                Button {
                    card.isFavorite.toggle()
                    CardStore.save(modelContext)
                } label: {
                    Label(card.isFavorite ? "Remove Favourite" : "Add Favourite", systemImage: card.isFavorite ? "star.slash" : "star")
                }
                Divider()
            }
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
        .disabled(isAdvancing)
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
        advanceTask?.cancel()
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
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
            isRevealed.toggle()
        }
    }

    private func grade(knewIt: Bool) {
        guard !isAdvancing, let card = currentCard else { return }
        do {
            try StudyStore.review(card, correct: knewIt, in: modelContext)
        } catch {
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7)) {
                dragOffset = .zero
            }
            saveError = error.localizedDescription
            return
        }
        isAdvancing = true
        if knewIt {
            knownCount += 1
        } else {
            missed.append(card)
        }

        let exitDistance: CGFloat = knewIt ? 700 : -700
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.22)) {
            dragOffset = CGSize(width: exitDistance, height: dragOffset.height)
        }
        advanceTask = Task { @MainActor in
            if !reduceMotion {
                do { try await Task.sleep(for: .milliseconds(220)) }
                catch { return }
            }
            guard !Task.isCancelled else { return }
            isRevealed = false
            dragOffset = .zero
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
                index += 1
            }
            isAdvancing = false
            if index >= queue.count {
                CardStore.save(modelContext)
            }
        }
    }
}

#if DEBUG
#Preview("Study Session") {
    let data = PreviewData()
    return StudyView(session: StudySession(title: data.chapter.name, cards: data.chapter.sortedCards))
        .modelContainer(data.container)
}
#endif
