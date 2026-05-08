import SwiftUI

struct FanHandView<CardGesture: Gesture>: View {
    let human: Player
    let isMyTurn: Bool
    let showHints: Bool

    @Binding var selectedCards: [Card]
    @Binding var dragCardID: UUID?
    @Binding var dragOffset: CGSize

    let canPlay: (Card) -> Bool
    let onCardTap: (Card) -> Void
    let onCardDoubleTap: (Card) -> Void
    let cardGesture: (Card, Bool) -> CardGesture

    @Environment(\.gameScale) private var gs

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
        let playable = isMyTurn && canPlay(card)
        let isSelected = selectedCards.contains(card)
        let isDragTarget = dragCardID == card.id
        let isGroupedHand = isSelected && !isDragTarget && dragTargetHandIndex != nil
        let convergenceX = isGroupedHand ? CGFloat(dragTargetHandIndex! - index) * metrics.xStep : 0

        let hintNudge: CGFloat = (showHints && playable && !isSelected) ? -8 * gs : 0

        return CardView(
            card: card,
            faceUp: true,
            highlight: showHints && playable && !isSelected,
            selected: isSelected,
            dimmed: !isMyTurn
        )
        .rotationEffect(.degrees((isDragTarget || isGroupedHand) ? 0 : angle), anchor: .bottom)
        .offset(y: (isDragTarget || isGroupedHand) ? 0 : yOffset + hintNudge)
        .position(
            x: metrics.startX + CGFloat(index) * metrics.xStep + metrics.cardWidth / 2,
            y: height / 2
        )
        .offset(
            x: (isDragTarget || isGroupedHand) ? (dragOffset.width + convergenceX) : 0,
            y: (isDragTarget || isGroupedHand) ? dragOffset.height : 0
        )
        .scaleEffect((isDragTarget || isGroupedHand) ? 1.12 : 1.0)
        .zIndex(isDragTarget ? 200 : (isGroupedHand ? 150 : (isSelected ? 100 : Double(index))))
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
}

private struct FanMetrics {
    let cardCount: Int
    let availableWidth: CGFloat
    let scale: CGFloat

    var cardWidth: CGFloat { 56 * scale }

    var maxSpread: Double {
        min(Double(cardCount - 1) * 4.0, 28)
    }

    var totalFanWidth: CGFloat {
        min(availableWidth, CGFloat(cardCount) * 32)
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
