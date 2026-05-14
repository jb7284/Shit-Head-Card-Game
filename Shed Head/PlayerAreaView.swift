import SwiftUI

struct PlayerAreaView: View {
    let human: Player
    let isMyTurn: Bool
    let mustPickUp: Bool
    let openingCard: Card?
    let turnPulse: Bool
    let showHints: Bool
    let skippedPlayerID: String?
    let revealedFaceDownIndex: Int?
    let tutorialHighlightedCardIDs: Set<UUID>
    let tutorialActiveDemo: TutorialDemo?

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
    let onPickUpPile: () -> Void

    @Environment(\.gameScale) private var gs
    @State private var faceDownFlipProgress: CGFloat = 0
    @State private var tutorialMotionProgress: CGFloat = 0

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
                .modifier(InactiveHumanCardsModifier(active: isMyTurn))
            FanHandView(
                human: human,
                isMyTurn: isMyTurn,
                openingCard: openingCard,
                showHints: showHints,
                tutorialHighlightedCardIDs: tutorialHighlightedCardIDs,
                tutorialActiveDemo: tutorialActiveDemo,
                selectedCards: $selectedCards,
                dragCardID: $dragCardID,
                dragOffset: $dragOffset,
                canPlay: canPlay,
                onCardTap: onCardTap,
                onCardDoubleTap: onCardDoubleTap,
                cardGesture: playableCardGesture
            )
            .scaleEffect(isMyTurn ? 1.18 : 1.0, anchor: .bottom)
            .offset(y: isMyTurn ? -16 * gs : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isMyTurn)
            .overlay { mustPickUpOverlay }
            .padding(.horizontal, 4)
            .modifier(InactiveHumanCardsModifier(active: isMyTurn))
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .overlay {
            if skippedPlayerID == human.id {
                SkippedBadge()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .onChange(of: revealedFaceDownIndex) { _, newValue in
            if newValue != nil {
                withAnimation(.easeInOut(duration: 0.35)) {
                    faceDownFlipProgress = 1
                }
            } else {
                faceDownFlipProgress = 0
            }
        }
        .onAppear {
            restartTutorialMotion(for: tutorialActiveDemo)
        }
        .onChange(of: tutorialActiveDemo) { _, newValue in
            restartTutorialMotion(for: newValue)
        }
    }

    @ViewBuilder
    private var mustPickUpOverlay: some View {
        if mustPickUp {
            Button(action: onPickUpPile) {
                Text("Pick Up Pile")
                    .font(.system(size: 16 * gs, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20 * gs)
                    .padding(.vertical, 10 * gs)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.85))
                            .shadow(color: .red.opacity(0.5), radius: 8 * gs, y: 2 * gs)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1 * gs)
                    )
            }
            .buttonStyle(.plain)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var tableCards: some View {
        HStack(spacing: 6) {
            if !human.drawPile.isEmpty {
                DrawPileStack(count: human.drawPile.count, mini: false)
                    .reportDrawPileFrame(human.id)
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
                let isRevealing = revealedFaceDownIndex == index
                let rotation = isRevealing ? faceDownFlipProgress * 180 : 0

                ZStack {
                    CardView(
                        card: human.faceDown[index],
                        faceUp: false,
                        highlight: tutorialHighlightedCardIDs.contains(human.faceDown[index].uid),
                        small: true
                    )
                        .opacity(rotation < 90 ? 1 : 0)
                    CardView(card: human.faceDown[index], faceUp: true,
                             highlight: (isRevealing && rotation >= 90) || tutorialHighlightedCardIDs.contains(human.faceDown[index].uid),
                             small: true)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        .opacity(rotation >= 90 ? 1 : 0)
                }
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .scaleEffect(isRevealing ? 1.3 : tutorialFaceDownScale(for: human.faceDown[index]))
                .offset(y: tutorialFaceDownLift(for: human.faceDown[index]))
                .zIndex(isRevealing ? 10 : 0)
                .reportCardFrame(human.faceDown[index].uid)
                .hideIfInFlight(human.faceDown[index].uid)
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
        let isTutorialTarget = tutorialHighlightedCardIDs.contains(card.uid)
        let isSelected = selectedCards.contains(card)
        let isDragTarget = dragCardID == card.id
        let isGroupedFaceUp = isSelected && !isDragTarget && isDraggingFaceUp
        let tutorialLift = tutorialFaceUpLift(for: card, isInteracting: isDragTarget || isGroupedFaceUp)
        let convergenceX: CGFloat = {
            guard isGroupedFaceUp, let target = dragFaceUpIndex else { return 0 }
            return CGFloat(target - index) * faceUpSlotStep
        }()

        return CardView(
            card: card,
            faceUp: true,
            highlight: isTutorialTarget || (showHints && playable && !isSelected),
            selected: isSelected,
            small: true
        )
        .reportCardFrame(card.uid)
        .hideIfInFlight(card.uid)
        .offset(y: (isTutorialTarget ? -18 : -10) + tutorialLift)
        .offset(
            x: (isDragTarget || isGroupedFaceUp) ? dragOffset.width + convergenceX : 0,
            y: (isDragTarget || isGroupedFaceUp) ? dragOffset.height : 0
        )
        .scaleEffect((isDragTarget || isGroupedFaceUp) ? 1.2 : 1.0)
        .rejectionShake(card.uid)
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

    private func restartTutorialMotion(for demo: TutorialDemo?) {
        tutorialMotionProgress = 0
        guard demo != nil else { return }
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            tutorialMotionProgress = 1
        }
    }

    private func tutorialFaceUpLift(for card: Card, isInteracting: Bool) -> CGFloat {
        guard !isInteracting,
              tutorialHighlightedCardIDs.contains(card.uid),
              tutorialActiveDemo?.kind == .playCard || tutorialActiveDemo?.kind == .reverse
        else { return 0 }

        return -48 * gs * tutorialMotionProgress
    }

    private func tutorialFaceDownLift(for card: Card) -> CGFloat {
        guard tutorialHighlightedCardIDs.contains(card.uid),
              tutorialActiveDemo?.kind == .faceDown
        else { return 0 }

        return -10 * gs * tutorialMotionProgress
    }

    private func tutorialFaceDownScale(for card: Card) -> CGFloat {
        guard tutorialHighlightedCardIDs.contains(card.uid),
              tutorialActiveDemo?.kind == .faceDown
        else { return 1 }

        return 1 + 0.08 * tutorialMotionProgress
    }
}

private struct InactiveHumanCardsModifier: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .brightness(active ? 0 : -0.34)
            .saturation(active ? 1 : 0.48)
            .contrast(active ? 1 : 0.88)
    }
}
