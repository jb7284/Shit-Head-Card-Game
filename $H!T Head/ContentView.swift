import SwiftUI

struct ContentView: View {
    @State private var engine = GameEngine()
    @State private var selectedCards: [Card] = []
    @State private var difficulty: Difficulty = .medium
    @State private var flights = FlightOrchestrator()
    @State private var effects = EffectCoordinator()

    @State private var swapSelection: SwapSelection? = nil
    @State private var showRules = false
    @State private var dealRevealed = false
    @State private var dragCardID: UUID? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var aiTask: Task<Void, Never>?

    @Namespace private var swapNamespace

    private let springAnim = Animation.spring(response: 0.4, dampingFraction: 0.75)

    var body: some View {
        ZStack {
            FeltTableBackground()
                .ignoresSafeArea()

            GeometryReader { geo in
                let rawScale = min(geo.size.width / 520, geo.size.height / 400)
                let scale = min(max(rawScale, 0.8), 2.0)

                ZStack {
                    phaseContent
                        .frame(width: geo.size.width, height: geo.size.height)

                    ForEach(flights.activeFlights) { flight in
                        FlyingCardView(flight: flight, onComplete: flights.handleFlightComplete)
                    }

                    ForEach(Array(effects.burnedCards.enumerated()), id: \.element.uid) { index, card in
                        let scatter = CGFloat(index) * 0.15
                        CardView(card: card, faceUp: true)
                            .allowsHitTesting(false)
                            .position(
                                x: flights.pileFrame.midX + effects.burnFlyProgress * (400 + CGFloat(index) * 25),
                                y: flights.pileFrame.midY - effects.burnFlyProgress * (600 + CGFloat(index) * 15)
                            )
                            .rotationEffect(.degrees(effects.burnFlyProgress * (35 + Double(index) * 12)))
                            .scaleEffect(0.85 - effects.burnFlyProgress * 0.25 + scatter * 0.1)
                            .opacity(max(0, 1 - effects.burnFlyProgress * 1.6))
                            .zIndex(300)
                    }
                }
                .environment(\.gameScale, scale)
                .environment(\.inFlightCardIDs, flights.inFlightCardIDs)
                .environment(\.rejectionShakeID, effects.rejectionShakeID)
                .environment(\.rejectionShakeTrigger, effects.rejectionShakeTrigger)
                .coordinateSpace(name: gameCoordinateSpace)
                .frame(width: geo.size.width, height: geo.size.height)
                .onPreferenceChange(CardFramePreferenceKey.self) { flights.cardFrames = $0 }
                .onPreferenceChange(PileFramePreferenceKey.self) { flights.pileFrame = $0 }
                .onPreferenceChange(HandCenterPreferenceKey.self) { flights.handCenterFrames = $0 }
                .onPreferenceChange(DrawPileFramePreferenceKey.self) { flights.drawPileFrames = $0 }
            }
        }
        .overlay(alignment: .top) {
            if let message = effects.rejectionMessage {
                RejectionTooltip(message: message)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: engine.eventSerial) { _, _ in
            if engine.lastEvent == .skip, let skippedID = engine.skippedPlayerID {
                effects.showSkipped(playerID: skippedID)
            }
            effects.handle(engine.lastEvent,
                           playFlightDuration: flights.playFlightDuration,
                           isCurrentPlayerAI: engine.state.currentPlayer.isAI,
                           playDirection: engine.state.playDirection)
        }
        .onChange(of: engine.state.currentPlayerIndex) { _, _ in
            effects.restartTurnPulse()
        }
        .onChange(of: engine.state.turnNumber) { _, _ in
            triggerAI()
        }
        .onChange(of: engine.state.phase) { _, phase in
            if phase == .finished {
                flights.clearFlightsAfterAnimationsSettle {
                    engine.state.phase == .finished
                }
            }
        }
        .onAppear {
            effects.restartTurnPulse()
            triggerAI()
        }
        .onDisappear {
            aiTask?.cancel()
        }
        .overlay(alignment: .bottomLeading) {
            rulesButton
        }
        .sheet(isPresented: $showRules) {
            RulesSheet(isPresented: $showRules)
        }
        .overlay {
            if engine.state.phase == .finished {
                GameOverOverlay(
                    loser: engine.state.loser,
                    winner: engine.state.finishOrder.first,
                    turnCount: engine.state.turnNumber,
                    onPlayAgain: startGame
                )
                .transition(.opacity)
            }
        }
    }

    // MARK: - Phase Content

    @ViewBuilder
    private var phaseContent: some View {
        switch engine.state.phase {
        case .dealing:
            StartScreenView(
                difficulty: $difficulty,
                onDeal: startGame,
                onShowRules: { showRules = true }
            )
        case .swapping:
            if let human = humanPlayer {
                SwapPhaseView(
                    human: human,
                    selection: $swapSelection,
                    dealRevealed: $dealRevealed,
                    namespace: swapNamespace,
                    onTapCard: handleSwapTap,
                    onSwap: handleSwapDrag,
                    onReady: confirmSwap
                )
            }
        case .playing, .finished:
            GameTableView(
                engine: engine,
                selectedCards: $selectedCards,
                dragCardID: $dragCardID,
                dragOffset: $dragOffset,
                burnEffect: effects.burnEffect,
                wildEffect: effects.wildEffect,
                reverseEffect: effects.reverseEffect,
                reverseDirection: effects.reverseDirection,
                turnPulse: effects.turnPulse,
                skippedPlayerID: effects.skippedPlayerID,
                revealedFaceDownIndex: effects.revealedFaceDownIndex,
                pendingBurnPile: effects.pendingBurnPile,
                onPickUpPile: pickUpPile,
                onFaceDownTap: playFaceDownCard,
                onCardTap: handleCardTap,
                onCardDoubleTap: handleCardDoubleTap,
                onDragStart: beginCardDrag,
                onDragUpdate: updateCardDrag,
                onDragEnd: endCardDrag
            )
        }
    }

    @ViewBuilder
    private var rulesButton: some View {
        if engine.state.phase == .playing || engine.state.phase == .finished {
            Button {
                showRules = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 13, weight: .medium))
                    Text("Rules")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }

    private var humanPlayer: Player? {
        engine.state.players.first(where: { !$0.isAI })
    }

    // MARK: - Game Lifecycle

    private func startGame() {
        selectedCards.removeAll()
        flights.reset()
        dealRevealed = false
        withAnimation(springAnim) {
            engine.startNewGame(playerCount: 4, difficulty: difficulty)
        }
    }

    private func confirmSwap() {
        swapSelection = nil
        dealRevealed = false
        withAnimation(springAnim) {
            engine.confirmSwap()
        }
        effects.restartTurnPulse()
        triggerAI()
    }

    // MARK: - Swap Phase

    private func handleSwapDrag(handIndex: Int, faceUpIndex: Int) {
        withAnimation(springAnim) {
            engine.swapCards(handIndex: handIndex, faceUpIndex: faceUpIndex)
        }
        swapSelection = nil
    }

    private func handleSwapTap(isFaceUp: Bool, index: Int) {
        let tapped: SwapSelection = isFaceUp ? .faceUp(index) : .hand(index)

        guard let current = swapSelection else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                swapSelection = tapped
            }
            return
        }

        switch (current, tapped) {
        case (.hand(let h), .faceUp(let f)):
            withAnimation(springAnim) { engine.swapCards(handIndex: h, faceUpIndex: f) }
            swapSelection = nil
        case (.faceUp(let f), .hand(let h)):
            withAnimation(springAnim) { engine.swapCards(handIndex: h, faceUpIndex: f) }
            swapSelection = nil
        default:
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                swapSelection = current == tapped ? nil : tapped
            }
        }
    }

    // MARK: - Play Actions

    private func pickUpPile() {
        selectedCards.removeAll()
        effects.prepareForAction(savingPileFrom: engine)
        let pre = flights.snapshot(from: engine)
        withAnimation(springAnim) {
            engine.pickUpPile()
        }
        let post = flights.snapshot(from: engine)
        flights.spawnFlights(flights.computeFlights(pre: pre, post: post))
        effects.triggerHaptic(.levelChange)
        triggerAI()
    }

    private func playFaceDownCard(at index: Int) {
        guard effects.revealedFaceDownIndex == nil else { return }

        effects.revealedFaceDownIndex = index

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))

            effects.revealedFaceDownIndex = nil
            effects.prepareForAction(savingPileFrom: engine)
            let pre = flights.snapshot(from: engine)
            withAnimation(springAnim) {
                engine.playFaceDownAt(index: index)
            }
            let post = flights.snapshot(from: engine)
            flights.spawnFlights(flights.computeFlights(pre: pre, post: post))
            effects.setupPendingBurn(pre: pre, post: post, lastEvent: engine.lastEvent)
            if engine.lastEvent == .failedFlip {
                effects.triggerHaptic(.levelChange)
            }
            triggerAI()
        }
    }

    private func playSelectedCards() {
        effects.prepareForAction(savingPileFrom: engine)
        let pre = flights.snapshot(from: engine)
        withAnimation(springAnim) {
            engine.playCards(selectedCards)
            selectedCards.removeAll()
        }
        let post = flights.snapshot(from: engine)
        flights.spawnFlights(flights.computeFlights(pre: pre, post: post))
        effects.setupPendingBurn(pre: pre, post: post, lastEvent: engine.lastEvent)
        effects.scheduleDrawHaptic(pre: pre, post: post)
        triggerAI()
    }

    // MARK: - Card Selection & Drag

    private func handleCardTap(_ card: Card) {
        guard engine.canPlay(card) else {
            effects.triggerRejectionFeedback(for: card, engine: engine)
            return
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            toggleSelection(for: card)
        }
    }

    private func handleCardDoubleTap(_ card: Card) {
        guard engine.canPlay(card) else {
            effects.triggerRejectionFeedback(for: card, engine: engine)
            return
        }
        if selectedCards.isEmpty || selectedCards[0].rank != card.rank {
            selectedCards = [card]
        } else if !selectedCards.contains(card) {
            selectedCards.append(card)
        }
        playSelectedCards()
    }

    private func beginCardDrag(_ card: Card) {
        guard engine.canPlay(card) else {
            effects.triggerRejectionFeedback(for: card, engine: engine)
            return
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            if !selectedCards.contains(card) {
                selectOnlyCompatible(card)
            }
            dragCardID = card.id
        }
    }

    private func updateCardDrag(_ translation: CGSize) {
        dragOffset = translation
    }

    private func endCardDrag(_ translation: CGSize) {
        if translation.height < -50 && !selectedCards.isEmpty {
            playSelectedCards()
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = .zero
            dragCardID = nil
        }
    }

    private func toggleSelection(for card: Card) {
        if selectedCards.contains(card) {
            selectedCards.removeAll { $0 == card }
        } else {
            selectOnlyCompatible(card)
        }
    }

    private func selectOnlyCompatible(_ card: Card) {
        if selectedCards.isEmpty || card.rank == selectedCards[0].rank {
            selectedCards.append(card)
        } else {
            selectedCards = [card]
        }
    }

    // MARK: - AI

    private func triggerAI() {
        aiTask?.cancel()
        guard engine.state.phase == .playing,
              !engine.state.players.isEmpty,
              engine.state.currentPlayer.isAI
        else { return }

        let humanOut = !(humanPlayer?.hasCards ?? false)
        let burnPending = !effects.pendingBurnPile.isEmpty
        let delayMs = burnPending ? 1800 : (humanOut ? 75 : 1200)

        aiTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMs))
            guard !Task.isCancelled,
                  engine.state.phase == .playing,
                  engine.state.currentPlayer.isAI
            else { return }

            effects.prepareForAction(savingPileFrom: engine)
            let pre = flights.snapshot(from: engine)
            withAnimation(springAnim) {
                engine.performAITurn()
            }
            let post = flights.snapshot(from: engine)
            flights.spawnFlights(flights.computeFlights(pre: pre, post: post))
            effects.setupPendingBurn(pre: pre, post: post, lastEvent: engine.lastEvent)
            triggerAI()
        }
    }
}

#Preview {
    ContentView()
}
