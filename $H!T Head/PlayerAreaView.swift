import SwiftUI

struct PlayerAreaView: View {
    let human: Player
    let isMyTurn: Bool
    let turnPulse: Bool
    let showHints: Bool

    @Binding var selectedCards: [Card]
    @Binding var dragCardID: UUID?
    @Binding var dragOffset: CGSize

    let canPlay: (Card) -> Bool
    let onFaceDownTap: (Int) -> Void
    let onCardTap: (Card) -> Void
    let onCardDoubleTap: (Card) -> Void
    let onDragStart: (Card) -> Void
    let onDragUpdate: (CGSize) -> Void
    let onDragEnd: (CGSize) -> Void

    @Environment(\.gameScale) private var gs

    private var isDraggingFaceUp: Bool {
        dragCardID != nil && human.faceUp.contains(where: { $0.id == dragCardID })
    }

    private var dragFaceUpIndex: Int? {
        guard let dragCardID else { return nil }
        return human.faceUp.firstIndex(where: { $0.id == dragCardID })
    }

    // Small card width (38 * gs) plus the HStack spacing (6).
    private var faceUpSlotStep: CGFloat { 38 * gs + 6 }

    var body: some View {
        VStack(spacing: 2) {
            tableCards
            FanHandView(
                human: human,
                isMyTurn: isMyTurn,
                showHints: showHints,
                selectedCards: $selectedCards,
                dragCardID: $dragCardID,
                dragOffset: $dragOffset,
                canPlay: canPlay,
                onCardTap: onCardTap,
                onCardDoubleTap: onCardDoubleTap,
                cardGesture: playableCardGesture
            )
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }

    private var tableCards: some View {
        HStack(spacing: 6) {
            if !human.drawPile.isEmpty {
                DrawPileStack(count: human.drawPile.count, mini: false)
                    .padding(.trailing, 10)
            }
            ForEach(0..<3, id: \.self) { index in
                tableCardSlot(index)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func tableCardSlot(_ index: Int) -> some View {
        let isPlayingFaceUp = human.playingFrom == .faceUp && isMyTurn

        let slot = ZStack {
            if index < human.faceDown.count {
                CardView(card: human.faceDown[index], faceUp: false, small: true)
            }
            if index < human.faceUp.count {
                faceUpCard(human.faceUp[index], index: index, isPlayingFaceUp: isPlayingFaceUp)
            }
        }
        .onTapGesture(count: 2) {
            guard isMyTurn, isPlayingFaceUp, index < human.faceUp.count else { return }
            onCardDoubleTap(human.faceUp[index])
        }
        .onTapGesture {
            guard isMyTurn else { return }
            if human.playingFrom == .faceDown, index < human.faceDown.count {
                onFaceDownTap(index)
            } else if isPlayingFaceUp, index < human.faceUp.count {
                onCardTap(human.faceUp[index])
            }
        }

        if index < human.faceUp.count {
            slot.gesture(playableCardGesture(for: human.faceUp[index], enabled: isPlayingFaceUp))
        } else {
            slot
        }
    }

    private func faceUpCard(_ card: Card, index: Int, isPlayingFaceUp: Bool) -> some View {
        let playable = isPlayingFaceUp && canPlay(card)
        let isSelected = selectedCards.contains(card)
        let isDragTarget = dragCardID == card.id
        let isGroupedFaceUp = isSelected && !isDragTarget && isDraggingFaceUp
        let convergenceX: CGFloat = {
            guard isGroupedFaceUp, let target = dragFaceUpIndex else { return 0 }
            return CGFloat(target - index) * faceUpSlotStep
        }()

        return CardView(
            card: card,
            faceUp: true,
            highlight: showHints && playable && !isSelected,
            selected: isSelected,
            small: true
        )
        .offset(y: -10)
        .offset(
            x: (isDragTarget || isGroupedFaceUp) ? dragOffset.width + convergenceX : 0,
            y: (isDragTarget || isGroupedFaceUp) ? dragOffset.height : 0
        )
        .scaleEffect((isDragTarget || isGroupedFaceUp) ? 1.2 : 1.0)
        .zIndex(isDragTarget ? 200 : (isGroupedFaceUp ? 150 : (isSelected ? 100 : 0)))
    }

    private func playableCardGesture(for card: Card, enabled: Bool) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard enabled, canPlay(card) else { return }
                if dragCardID == nil {
                    onDragStart(card)
                }
                onDragUpdate(value.translation)
            }
            .onEnded { value in
                guard enabled else { return }
                onDragEnd(value.translation)
            }
    }
}
