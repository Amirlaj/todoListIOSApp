import SwiftUI

/// A two-sided card that flips around its vertical axis.
struct FlipCardView: View {
    let front: String
    let back: String
    var frontCaption = "Question"
    var backCaption = "Answer"
    let isFlipped: Bool

    var body: some View {
        ZStack {
            CardFaceView(text: front, caption: frontCaption, systemImage: "questionmark.circle", tint: .accentColor)
                .modifier(FlipFaceModifier(angle: isFlipped ? 180 : 0, isBackFace: false))
            CardFaceView(text: back, caption: backCaption, systemImage: "lightbulb", tint: .green)
                .modifier(FlipFaceModifier(angle: isFlipped ? 180 : 0, isBackFace: true))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(isFlipped ? Text("") : Text("Double tap to show the answer"))
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityText: String {
        isFlipped ? "\(backCaption): \(back)" : "\(frontCaption): \(front)"
    }
}

/// Rotates one face of the card and only shows it while it faces the viewer.
private struct FlipFaceModifier: ViewModifier, Animatable {
    var angle: Double
    let isBackFace: Bool

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        let showsBack = angle >= 90
        content
            .rotation3DEffect(
                .degrees(isBackFace ? angle - 180 : angle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.4
            )
            .opacity(showsBack == isBackFace ? 1 : 0)
    }
}

private struct CardFaceView: View {
    let text: String
    let caption: String
    let systemImage: String
    let tint: Color

    private var isLong: Bool {
        text.count > 140 || text.contains("\n")
    }

    private var font: Font {
        switch text.count {
        case ..<40: .title.weight(.semibold)
        case ..<140: .title3.weight(.medium)
        default: .body
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(caption.uppercased(), systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .padding([.top, .horizontal], 20)

            GeometryReader { proxy in
                ScrollView {
                    MarkdownText(text)
                        .font(font)
                        .multilineTextAlignment(isLong ? .leading : .center)
                        .frame(maxWidth: .infinity, alignment: isLong ? .leading : .center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .frame(minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1.5)
        }
    }
}

#if DEBUG
#Preview("Question") {
    FlipCardView(
        front: "What is a cell?",
        back: "The smallest **structural and functional unit** of a living organism.",
        isFlipped: false
    )
    .frame(height: 400)
    .padding(24)
}

#Preview("Answer") {
    FlipCardView(
        front: "Mitochondria",
        back: "- Produce energy (ATP) through cellular respiration\n- Have their own DNA",
        isFlipped: true
    )
    .frame(height: 400)
    .padding(24)
}
#endif
