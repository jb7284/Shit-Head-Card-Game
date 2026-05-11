import SwiftUI

struct SwapPhaseView: View {
    let human: Player
    @Binding var selection: SwapSelection?
    @Binding var dealRevealed: Bool
    let namespace: Namespace.ID
    let onTapCard: (_ isFaceUp: Bool, _ index: Int) -> Void
    let onSwap: (_ handIndex: Int, _ faceUpIndex: Int) -> Void
    let onReady: () -> Void

    @State private var dragSource: SwapSelection? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var cardFrames: [String: CGRect] = [:]

    private let swapSpace = "swapArea"

    var body: some View {
        VStack(spacing: 10) {
            header
            Spacer(minLength: 0)
            tableCards
            Spacer(minLength: 0)
            handCards
            Spacer(minLength: 0)
            readyButton
        }
        .coordinateSpace(name: swapSpace)
        .onPreferenceChange(SwapFrameKey.self) { cardFrames = $0 }
        .padding(.horizontal, 8)
        .padding(.top, 44)
        .padding(.bottom, 40)
        .onAppear { dealRevealed = true }
    }

    private var header: some View {
        VStack(spacing: 2) {
            GoldShimmerText(
                text: "SWITCH CARDS",
                font: .system(size: 20, weight: .black, design: .serif)
            )
            .opacity(dealRevealed ? 1 : 0)
            .animation(.easeOut.delay(0.4), value: dealRevealed)

            Text("Drag or tap cards to swap between hand and table.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .opacity(dealRevealed ? 1 : 0)
                .animation(.easeOut.delay(0.5), value: dealRevealed)
        }
    }

    private var tableCards: some View {
        VStack(spacing: 3) {
            sectionLabel("TABLE CARDS")
                .padding(.bottom, 10)

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    tableCardSlot(index)
                }
            }
        }
    }

    private var handCards: some View {
        VStack(spacing: 3) {
            sectionLabel("YOUR HAND")

            HStack(spacing: 10) {
                ForEach(Array(human.hand.enumerated()), id: \.element.id) { index, card in
                    handCardSlot(card, index: index)
                }
            }
        }
    }

    private var readyButton: some View {
        PrimaryGameButton(
            width: 120,
            height: 36,
            cornerRadius: 10,
            shadowRadius: 6,
            shadowY: 2,
            action: onReady
        ) {
            Text("Ready")
                .font(.system(size: 14, weight: .black, design: .serif))
        }
        .opacity(dealRevealed ? 1 : 0)
        .animation(.easeIn.delay(0.6), value: dealRevealed)
    }

    // MARK: - Card Slots

    private func tableCardSlot(_ index: Int) -> some View {
        let isDragging = dragSource == .faceUp(index)
        let isTarget = currentDropTarget == .faceUp(index)

        return ZStack {
            if index < human.faceDown.count {
                CardView(card: human.faceDown[index], faceUp: false)
            }
            if index < human.faceUp.count {
                CardView(
                    card: human.faceUp[index],
                    faceUp: true,
                    selected: selection == .faceUp(index) || isTarget
                )
                .matchedGeometryEffect(id: human.faceUp[index].id, in: namespace)
                .offset(y: -8)
            }
        }
        .opacity(dealRevealed ? 1 : 0)
        .offset(y: dealRevealed ? 0 : -30)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1), value: dealRevealed)
        .background(frameReader("table\(index)"))
        .offset(isDragging ? dragOffset : .zero)
        .scaleEffect(isDragging ? 1.08 : (isTarget ? 1.05 : 1.0))
        .zIndex(isDragging ? 100 : 0)
        .onTapGesture { onTapCard(true, index) }
        .gesture(swapDragGesture(source: .faceUp(index)))
    }

    private func handCardSlot(_ card: Card, index: Int) -> some View {
        let isDragging = dragSource == .hand(index)
        let isTarget = currentDropTarget == .hand(index)

        return CardView(
            card: card,
            faceUp: true,
            selected: selection == .hand(index) || isTarget
        )
        .matchedGeometryEffect(id: card.id, in: namespace)
        .opacity(dealRevealed ? 1 : 0)
        .offset(y: dealRevealed ? 0 : 30)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.7).delay(0.3 + Double(index) * 0.1),
            value: dealRevealed
        )
        .background(frameReader("hand\(index)"))
        .offset(isDragging ? dragOffset : .zero)
        .scaleEffect(isDragging ? 1.08 : (isTarget ? 1.05 : 1.0))
        .zIndex(isDragging ? 100 : 0)
        .onTapGesture { onTapCard(false, index) }
        .gesture(swapDragGesture(source: .hand(index)))
    }

    // MARK: - Drag Logic

    private var currentDropTarget: SwapSelection? {
        guard let source = dragSource else { return nil }
        return findTarget(from: source, translation: dragOffset)
    }

    private func swapDragGesture(source: SwapSelection) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if dragSource == nil {
                    withAnimation(.easeOut(duration: 0.15)) {
                        dragSource = source
                    }
                    selection = nil
                }
                dragOffset = value.translation
            }
            .onEnded { value in
                if let target = findTarget(from: source, translation: value.translation) {
                    performSwap(source: source, target: target)
                }
                withAnimation(GameTheme.snappySpring) {
                    dragSource = nil
                    dragOffset = .zero
                }
            }
    }

    private func findTarget(from source: SwapSelection, translation: CGSize) -> SwapSelection? {
        let sourceKey: String
        switch source {
        case .hand(let i): sourceKey = "hand\(i)"
        case .faceUp(let i): sourceKey = "table\(i)"
        }

        guard let sourceFrame = cardFrames[sourceKey] else { return nil }

        let dropPoint = CGPoint(
            x: sourceFrame.midX + translation.width,
            y: sourceFrame.midY + translation.height
        )

        switch source {
        case .hand:
            for i in 0..<min(3, human.faceUp.count) {
                if let frame = cardFrames["table\(i)"],
                   frame.insetBy(dx: -20, dy: -20).contains(dropPoint) {
                    return .faceUp(i)
                }
            }
        case .faceUp:
            for i in 0..<human.hand.count {
                if let frame = cardFrames["hand\(i)"],
                   frame.insetBy(dx: -20, dy: -20).contains(dropPoint) {
                    return .hand(i)
                }
            }
        }
        return nil
    }

    private func performSwap(source: SwapSelection, target: SwapSelection) {
        switch (source, target) {
        case (.hand(let h), .faceUp(let f)),
             (.faceUp(let f), .hand(let h)):
            onSwap(h, f)
        default:
            break
        }
    }

    // MARK: - Frame Tracking

    private func frameReader(_ key: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: SwapFrameKey.self,
                value: [key: geo.frame(in: .named(swapSpace))]
            )
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        GoldShimmerText(
            text: title,
            font: .system(size: 12, weight: .black, design: .serif)
        )
        .opacity(dealRevealed ? 1 : 0)
    }
}

private struct SwapFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
