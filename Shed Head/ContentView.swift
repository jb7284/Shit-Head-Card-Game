import SwiftUI

struct ContentView: View {
    @State private var engine = GameEngine()
    @State private var selectedCards: [Card] = []
    @State private var gameplayMode: GameplayMode = .play
    @State private var flights = FlightOrchestrator()
    @State private var effects = EffectCoordinator()
    @State private var tutorial = TutorialModeController()
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = true
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    @State private var swapSelection: SwapSelection? = nil
    @State private var showRules = false
    @State private var showTutorial = false
    @State private var dealRevealed = false
    @State private var dragCardID: UUID? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var aiTask: Task<Void, Never>?

    @Namespace private var swapNamespace

    private let springAnim = Animation.spring(response: 0.4, dampingFraction: 0.75)

    var body: some View {
        ZStack {
            Image(engine.state.phase == .playing || engine.state.phase == .finished ? "playing_background" : "table_background")
                .resizable()
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
                        burnedCardView(card, index: index)
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
                effects.showSkipped(playerID: skippedID, emphasis: tutorial.isActive)
            }
            effects.handle(engine.lastEvent,
                           playFlightDuration: flights.playFlightDuration,
                           isCurrentPlayerAI: engine.state.currentPlayer.isAI,
                           playDirection: engine.state.playDirection,
                           isFastPaced: !(humanPlayer?.hasCards ?? false),
                           isFourOfAKindBurn: engine.lastBurnWasFourOfAKind)
        }
        .onChange(of: engine.state.currentPlayerIndex) { _, _ in
            effects.restartTurnPulse()
            evaluateTutorialLesson()
        }
        .onChange(of: engine.state.turnNumber) { _, _ in
            evaluateTutorialLesson()
            triggerAI()
        }
        .onChange(of: engine.state.phase) { _, phase in
            if phase == .finished {
                flights.clearFlightsAfterAnimationsSettle {
                    engine.state.phase == .finished
                }
            }
            evaluateTutorialLesson()
        }
        .onAppear {
            SoundManager.isEnabled = soundEffectsEnabled
            effects.restartTurnPulse()
            triggerAI()
        }
        .onChange(of: soundEffectsEnabled) { _, enabled in
            SoundManager.isEnabled = enabled
        }
        .onChange(of: tutorial.activeDemo) { _, demo in
            guard demo != nil else { return }
            scheduleTutorialDemoCompletion()
        }
        .onDisappear {
            aiTask?.cancel()
        }
        .overlay(alignment: .bottomLeading) {
            gameplayMenu
        }
        .sheet(isPresented: $showRules) {
            RulesSheet(isPresented: $showRules)
        }
        .sheet(isPresented: $showTutorial) {
            TutorialSheet(
                onFinish: {
                    hasSeenTutorial = true
                    showTutorial = false
                },
                onStartTutorialMode: {
                    hasSeenTutorial = true
                    showTutorial = false
                    startGame(mode: .tutorialMode)
                }
            )
        }
        .overlay {
            if engine.state.phase == .finished {
                GameOverOverlay(
                    loser: engine.state.loser,
                    winner: engine.state.finishOrder.first,
                    onPlayAgain: { startGame() }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if let jokerIndex = engine.pendingJokerPlayerIndex, !engine.state.players[jokerIndex].isAI {
                JokerTargetPicker(
                    players: engine.state.players,
                    jokerPlayerIndex: jokerIndex,
                    pileCount: effects.lastPileSnapshot.count,
                    onSelect: handleJokerTarget
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if let overlay = tutorial.currentOverlay {
                TutorialCoachOverlay(content: overlay, onContinue: continueTutorialOverlay)
                    .transition(.opacity)
                    .zIndex(700)
            }
        }
        .overlay {
            if let demo = tutorial.activeDemo {
                TutorialDemoOverlay(demo: demo)
                    .transition(.opacity)
                    .zIndex(650)
            }
        }
    }

    // MARK: - Phase Content

    @ViewBuilder
    private var phaseContent: some View {
        switch engine.state.phase {
        case .dealing:
            StartScreenView(
                gameplayMode: $gameplayMode,
                onDeal: { startGame() },
                onShowRules: { showRules = true },
                onShowTutorial: { showTutorial = true }
            )
        case .swapping:
            if let human = humanPlayer {
                SwapPhaseView(
                    human: human,
                    selection: $swapSelection,
                    dealRevealed: $dealRevealed,
                    tutorialHighlightedCardIDs: tutorial.highlightedCardIDs,
                    tutorialActiveDemo: tutorial.activeDemo,
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
                fourOfAKindEffect: effects.fourOfAKindEffect,
                reverseEffect: effects.reverseEffect,
                reverseDirection: effects.reverseDirection,
                turnPulse: effects.turnPulse,
                skippedPlayerID: effects.skippedPlayerID,
                revealedFaceDownIndex: effects.revealedFaceDownIndex,
                pendingBurnPile: effects.pendingBurnPile,
                tutorialHighlightedCardIDs: tutorial.highlightedCardIDs,
                tutorialActiveDemo: tutorial.activeDemo,
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
    private var gameplayMenu: some View {
        if engine.state.phase == .playing || engine.state.phase == .finished {
            Menu {
                Button {
                    showTutorial = true
                } label: {
                    Label("Tutorial", systemImage: "graduationcap.fill")
                }

                Button {
                    showRules = true
                } label: {
                    Label("Rules", systemImage: "list.bullet.rectangle")
                }

                Button(role: .destructive) {
                    restartGame()
                } label: {
                    Label("Restart Game", systemImage: "arrow.clockwise")
                }

                Toggle(isOn: $soundEffectsEnabled) {
                    Label(
                        soundEffectsEnabled ? "Sound Effects On" : "Sound Effects Off",
                        systemImage: soundEffectsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
                    )
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13, weight: .medium))
                    Text("Menu")
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

    private func burnedCardView(_ card: Card, index: Int) -> some View {
        let progress = effects.burnFlyProgress
        let scatter = CGFloat(index) * 0.15
        let xOffset = progress * (400 + CGFloat(index) * 25)
        let yOffset = progress * (600 + CGFloat(index) * 15)
        let rotation = progress * (35 + Double(index) * 12)
        let scale = 0.85 - progress * 0.25 + scatter * 0.1
        let opacity = max(0, 1 - progress * 1.6)

        return CardView(card: card, faceUp: true)
            .allowsHitTesting(false)
            .position(x: flights.pileFrame.midX + xOffset, y: flights.pileFrame.midY - yOffset)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(opacity)
            .zIndex(300)
    }

    // MARK: - Game Lifecycle

    private func startGame(mode selectedMode: GameplayMode? = nil) {
        if let selectedMode {
            gameplayMode = selectedMode
        }
        let selectedGameplayMode = selectedMode ?? gameplayMode
        aiTask?.cancel()
        selectedCards.removeAll()
        swapSelection = nil
        dragCardID = nil
        dragOffset = .zero
        flights.reset()
        effects = EffectCoordinator()
        dealRevealed = false
        withAnimation(springAnim) {
            if selectedGameplayMode == .tutorialMode {
                engine.startTutorialGame(playerCount: 4)
                tutorial.start()
            } else {
                engine.startNewGame(playerCount: 4, difficulty: selectedGameplayMode.difficulty)
                tutorial.stop()
            }
        }
    }

    private func restartGame() {
        aiTask?.cancel()
        swapSelection = nil
        dragCardID = nil
        dragOffset = .zero
        startGame()
        effects.restartTurnPulse()
        triggerAI()
    }

    private func confirmSwap() {
        guard !tutorial.blocksInput else { return }
        swapSelection = nil
        dealRevealed = false
        withAnimation(springAnim) {
            engine.confirmSwap()
            if tutorial.isActive {
                engine.forceHumanTutorialTurn()
            }
        }
        effects.restartTurnPulse()
        evaluateTutorialLesson()
        triggerAI()
    }

    // MARK: - Swap Phase

    private func handleSwapDrag(handIndex: Int, faceUpIndex: Int) {
        guard !tutorial.blocksInput else { return }
        withAnimation(springAnim) {
            engine.swapCards(handIndex: handIndex, faceUpIndex: faceUpIndex)
        }
        swapSelection = nil
    }

    private func handleSwapTap(isFaceUp: Bool, index: Int) {
        guard !tutorial.blocksInput else { return }
        let tapped: SwapSelection = isFaceUp ? .faceUp(index) : .hand(index)

        guard let current = swapSelection else {
            withAnimation(GameTheme.quickSpring) {
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
            withAnimation(GameTheme.quickSpring) {
                swapSelection = current == tapped ? nil : tapped
            }
        }
    }

    // MARK: - Play Actions

    private typealias Snapshot = FlightOrchestrator.StateSnapshot

    private func animateAction(
        _ action: () -> Void,
        after: ((_ pre: Snapshot, _ post: Snapshot) -> Void)? = nil
    ) {
        effects.prepareForAction(savingPileFrom: engine)
        let pre = flights.snapshot(from: engine)
        withAnimation(springAnim) { action() }
        let post = flights.snapshot(from: engine)
        flights.spawnFlights(flights.computeFlights(pre: pre, post: post))
        after?(pre, post)
    }

    private func pickUpPile() {
        guard !tutorial.blocksInput else { return }
        selectedCards.removeAll()
        animateAction { engine.pickUpPile() }
        tutorial.markPlayerActed()
        effects.triggerHaptic(.levelChange)
        evaluateTutorialLesson()
        triggerAI()
    }

    private func playFaceDownCard(at index: Int) {
        guard !tutorial.blocksInput else { return }
        guard effects.revealedFaceDownIndex == nil else { return }

        effects.revealedFaceDownIndex = index

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))

            effects.revealedFaceDownIndex = nil
            animateAction {
                engine.playFaceDownAt(index: index)
            } after: { pre, post in
                effects.setupPendingBurn(pre: pre, post: post, lastEvent: engine.lastEvent)
            }
            if engine.lastEvent == .failedFlip {
                effects.triggerHaptic(.levelChange)
            }
            tutorial.markPlayerActed()
            evaluateTutorialLesson()
            triggerAI()
        }
    }

    private func playSelectedCards() {
        guard !tutorial.blocksInput else { return }
        animateAction {
            engine.playCards(selectedCards)
            selectedCards.removeAll()
        } after: { pre, post in
            effects.setupPendingBurn(pre: pre, post: post, lastEvent: engine.lastEvent)
            effects.scheduleDrawHaptic(pre: pre, post: post)
        }
        tutorial.markPlayerActed()
        evaluateTutorialLesson()
        triggerAI()
    }

    // MARK: - Joker

    private func handleJokerTarget(_ targetIndex: Int) {
        guard !tutorial.blocksInput else { return }
        animateAction { engine.assignJokerPile(to: targetIndex) }
        tutorial.markPlayerActed()
        evaluateTutorialLesson()
        triggerAI()
    }

    // MARK: - Card Selection & Drag

    private func handleCardTap(_ card: Card) {
        guard !tutorial.blocksInput else { return }
        guard engine.canPlay(card) else {
            effects.triggerRejectionFeedback(for: card, engine: engine)
            return
        }
        withAnimation(GameTheme.quickSpring) {
            toggleSelection(for: card)
        }
    }

    private func handleCardDoubleTap(_ card: Card) {
        guard !tutorial.blocksInput else { return }
        guard engine.canPlay(card) else {
            effects.triggerRejectionFeedback(for: card, engine: engine)
            return
        }
        if let tutorialGroup = tutorial.highlightedPlayableGroup(tapped: card, engine: engine) {
            selectedCards = tutorialGroup
        } else {
            if selectedCards.isEmpty || selectedCards[0].rank != card.rank {
                selectedCards = [card]
            } else if !selectedCards.contains(card) {
                selectedCards.append(card)
            }
        }
        playSelectedCards()
    }

    private func beginCardDrag(_ card: Card) {
        guard !tutorial.blocksInput else { return }
        guard engine.canPlay(card) else {
            effects.triggerRejectionFeedback(for: card, engine: engine)
            return
        }
        withAnimation(GameTheme.quickSpring) {
            if !selectedCards.contains(card) {
                selectOnlyCompatible(card)
            }
            dragCardID = card.id
        }
    }

    private func updateCardDrag(_ translation: CGSize) {
        guard !tutorial.blocksInput else { return }
        dragOffset = translation
    }

    private func endCardDrag(_ translation: CGSize) {
        guard !tutorial.blocksInput else { return }
        if translation.height < -50 && !selectedCards.isEmpty {
            playSelectedCards()
        }
        withAnimation(GameTheme.snappySpring) {
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
              engine.state.currentPlayer.isAI,
              !tutorial.blocksAI
        else { return }

        let humanOut = !(humanPlayer?.hasCards ?? false)
        let burnPending = !effects.pendingBurnPile.isEmpty
        let delay = AIPacing.turnDelay(humanOut: humanOut, burnPending: burnPending)

        aiTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled,
                  engine.state.phase == .playing,
                  engine.state.currentPlayer.isAI
            else { return }

            animateAction {
                engine.performAITurn()
            } after: { pre, post in
                effects.setupPendingBurn(pre: pre, post: post, lastEvent: engine.lastEvent)
            }

            if let jokerIdx = engine.pendingJokerPlayerIndex, engine.state.players[jokerIdx].isAI {
                let target = engine.bestJokerTarget(playerIndex: jokerIdx)
                try? await Task.sleep(for: AIPacing.jokerDelay(humanOut: humanOut))
                guard !Task.isCancelled, engine.state.phase == .playing else { return }
                handleJokerTarget(target)
            } else {
                evaluateTutorialLesson()
                triggerAI()
            }
        }
    }

    // MARK: - Tutorial Mode

    private func continueTutorialOverlay() {
        withAnimation(GameTheme.snappySpring) {
            tutorial.dismissCurrentOverlay(engine: engine)
            syncTutorialSelectionHint()
        }
    }

    private func scheduleTutorialDemoCompletion() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            guard let demo = tutorial.activeDemo, !demo.repeatsUntilPlayerAction else { return }
            withAnimation(GameTheme.snappySpring) {
                tutorial.finishActiveDemo()
                syncTutorialSelectionHint()
            }
            evaluateTutorialLesson()
            triggerAI()
        }
    }

    private func evaluateTutorialLesson() {
        tutorial.showNextLessonIfNeeded(engine: engine)
        syncTutorialSelectionHint()
    }

    private func syncTutorialSelectionHint() {
        guard tutorial.isActive,
              let tutorialGroup = tutorial.highlightedPlayableGroup(engine: engine)
        else { return }
        selectedCards = tutorialGroup
    }
}

enum AIPacing {
    static func turnDelay(humanOut: Bool, burnPending: Bool) -> Duration {
        if humanOut {
            return .milliseconds(75)
        }
        return burnPending ? .milliseconds(1800) : .milliseconds(1200)
    }

    static func jokerDelay(humanOut: Bool) -> Duration {
        humanOut ? .milliseconds(75) : .milliseconds(1500)
    }

    static func burnEffectDelay(playFlightDuration: TimeInterval, humanOut: Bool) -> TimeInterval {
        humanOut ? 0.05 : playFlightDuration + 0.5
    }
}

#Preview {
    ContentView()
}
