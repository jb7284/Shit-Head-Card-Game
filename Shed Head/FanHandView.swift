import SwiftUI

struct FanHandView<CardGesture: Gesture>: View {
    let human: Player
    let isMyTurn: Bool
    let openingCard: Card?
    let showHints: Bool
    let tutorialHighlightedCardIDs: Set<UUID>
    let tutorialActiveDemo: TutorialDemo?

    @Binding var selectedCards: [Card]
    @Binding var dragCardID: UUID?
    @Binding var dragOffset: CGSize

    let canPlay: (Card) -> Bool
    let onCardTap: (Card) -> Void
    let onCardDoubleTap: (Card) -> Void
    let cardGesture: (Card, Bool) -> CardGesture

    @Environment(\.gameScale) private var gs
    @State private var tutorialMotionProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let metrics = FanMetrics(cardCount: human.hand.count, availableWidth: geo.size.width, scale: gs)

            ZStack {
                let dragTargetHandIndex = dragCardID.flatMap { id in
                    human.hand.firstIndex(where: { $0.id == id })
                }

                ForEach(Array(human.hand.enumerated()), id: \.element.id) { index, card in
                    handCard(
                        card,
                        index: index,
                        metrics: metrics,
                        dragTargetHandIndex: dragTargetHandIndex,
                        height: geo.size.height
                    )
                }
            }
        }
        .frame(height: 105 * gs)
        .reportHandCenter(human.id)
        .onAppear {
            restartTutorialMotion(for: tutorialActiveDemo)
        }
        .onChange(of: tutorialActiveDemo) { _, newValue in
            restartTutorialMotion(for: newValue)
        }
    }

    private func handCard(
        _ card: Card,
        index: Int,
        metrics: FanMetrics,
        dragTargetHandIndex: Int?,
        height: CGFloat
    ) -> some View {
        let progress = metrics.progress(for: index)
        let angle = metrics.angle(for: progress)
        let yOffset = metrics.yOffset(for: progress)
        let isOpening = openingCard == card
        let isTutorialTarget = tutorialHighlightedCardIDs.contains(card.uid)
        let playable = isMyTurn && canPlay(card)
        let isSelected = selectedCards.contains(card)
        let isDragTarget = dragCardID == card.id
        let isGroupedHand = isSelected && !isDragTarget && dragTargetHandIndex != nil
        let tutorialSelected = isTutorialMultiCardTarget(card)
        let isVisuallySelected = isSelected || tutorialSelected
        let tutorialMotion = tutorialMotionOffset(
            for: card,
            demoIndex: tutorialActiveDemo?.cards.firstIndex(where: { $0.uid == card.uid }),
            isInteracting: isDragTarget || isGroupedHand
        )
        let convergenceX: CGFloat = {
            guard isGroupedHand, let target = dragTargetHandIndex else { return 0 }
            return CGFloat(target - index) * metrics.xStep
        }()

        let hintNudge: CGFloat = (showHints && playable && !isSelected) ? -8 * gs : 0
        let openingNudge: CGFloat = isOpening ? -18 * gs : 0
        let tutorialNudge: CGFloat = isTutorialTarget ? -20 * gs : 0

        return CardView(
            card: card,
            faceUp: true,
            highlight: isTutorialTarget || isOpening || (showHints && playable && !isSelected),
            selected: isVisuallySelected,
            dimmed: isMyTurn && openingCard != nil && !isOpening
        )
        .reportCardFrame(card.uid)
        .hideIfInFlight(card.uid)
        .rotationEffect(.degrees((isDragTarget || isGroupedHand) ? 0 : angle), anchor: .bottom)
        .offset(
            x: (isDragTarget || isGroupedHand) ? 0 : tutorialMotion.width,
            y: (isDragTarget || isGroupedHand) ? 0 : yOffset + hintNudge + openingNudge + tutorialNudge + tutorialMotion.height
        )
        .position(
            x: metrics.startX + CGFloat(index) * metrics.xStep + metrics.cardWidth / 2,
            y: height / 2
        )
        .offset(
            x: (isDragTarget || isGroupedHand) ? (dragOffset.width + convergenceX) : 0,
            y: (isDragTarget || isGroupedHand) ? dragOffset.height : 0
        )
        .scaleEffect((isDragTarget || isGroupedHand) ? 1.12 : tutorialScale(for: card))
        .rejectionShake(card.uid)
        .zIndex(isDragTarget ? 200 : (isGroupedHand ? 150 : (isVisuallySelected ? 100 : Double(index))))
        .onTapGesture(count: 2) {
            guard isMyTurn else { return }
            onCardDoubleTap(card)
        }
        .onTapGesture {
            guard isMyTurn else { return }
            onCardTap(card)
        }
        .gesture(cardGesture(card, isMyTurn))
        .transition(.asymmetric(
            insertion: .scale(scale: 0.3).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }

    private func restartTutorialMotion(for demo: TutorialDemo?) {
        tutorialMotionProgress = 0
        guard demo != nil else { return }
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            tutorialMotionProgress = 1
        }
    }

    private func isTutorialMultiCardTarget(_ card: Card) -> Bool {
        tutorialActiveDemo?.kind == .multiCard && tutorialHighlightedCardIDs.contains(card.uid)
    }

    private func tutorialMotionOffset(for card: Card, demoIndex: Int?, isInteracting: Bool) -> CGSize {
        guard !isInteracting,
              tutorialHighlightedCardIDs.contains(card.uid),
              let demo = tutorialActiveDemo
        else { return .zero }

        switch demo.kind {
        case .playCard, .reverse:
            return CGSize(width: 0, height: -68 * gs * tutorialMotionProgress)
        case .multiCard:
            let cardIndex = CGFloat(demoIndex ?? 0)
            let centerIndex = CGFloat(max(demo.cards.count - 1, 0)) / 2
            let gather = (centerIndex - cardIndex) * 12 * gs * tutorialMotionProgress
            return CGSize(width: gather, height: -58 * gs * tutorialMotionProgress)
        default:
            return .zero
        }
    }

    private func tutorialScale(for card: Card) -> CGFloat {
        guard tutorialHighlightedCardIDs.contains(card.uid),
              let demo = tutorialActiveDemo,
              demo.kind == .playCard || demo.kind == .reverse || demo.kind == .multiCard
        else { return 1 }

        return 1 + 0.06 * tutorialMotionProgress
    }
}

private struct FanMetrics {
    let cardCount: Int
    let availableWidth: CGFloat
    let scale: CGFloat

    var cardWidth: CGFloat { 56 * scale }

    private var maxFanWidth: CGFloat { availableWidth * 0.75 }

    var maxSpread: Double {
        min(Double(cardCount - 1) * 4.0, 28)
    }

    var totalFanWidth: CGFloat {
        let natural = CGFloat(cardCount) * 32
        return min(natural, maxFanWidth)
    }

    var xStep: CGFloat {
        cardCount > 1 ? totalFanWidth / CGFloat(cardCount - 1) : 0
    }

    var startX: CGFloat {
        (availableWidth - totalFanWidth) / 2
    }

    func progress(for index: Int) -> Double {
        cardCount > 1 ? Double(index) / Double(cardCount - 1) : 0.5
    }

    func angle(for progress: Double) -> Double {
        (progress - 0.5) * maxSpread
    }

    func yOffset(for progress: Double) -> Double {
        let normalizedDistance = abs(progress - 0.5)
        return normalizedDistance * normalizedDistance * 12
    }
}
