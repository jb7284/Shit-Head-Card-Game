import SwiftUI

struct ContentView: View {
    @State private var engine = GameEngine()
    @State private var selectedCards: [Card] = []
    @State private var playerCount: Int = 2
    @State private var difficulty: Difficulty = .medium

    @State private var burnEffect = false
    @State private var wildEffect = false
    @State private var turnPulse = false
    @State private var swapSelection: SwapSelection? = nil
    @State private var showRules = false
    @State private var dealRevealed = false
    @State private var dragCardID: UUID? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var aiTask: Task<Void, Never>?

    @State private var cardFrames: [UUID: CGRect] = [:]
    @State private var pileFrame: CGRect = .zero
    @State private var handCenterFrames: [String: CGRect] = [:]
    @State private var inFlightCardIDs: Set<UUID> = []
    @State private var activeFlights: [CardFlight] = []

    @Namespace private var swapNamespace

    private let springAnim = Animation.spring(response: 0.4, dampingFraction: 0.75)
    private let playStaggerSeconds: TimeInterval = 0.085
    private let pickupStaggerSeconds: TimeInterval = 0.05
    private let playFlightDuration: TimeInterval = 0.45
    private let pickupFlightDuration: TimeInterval = 0.4

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

                    ForEach(activeFlights) { flight in
                        FlyingCardView(flight: flight, onComplete: handleFlightComplete)
                    }
                }
                .environment(\.gameScale, scale)
                .environment(\.inFlightCardIDs, inFlightCardIDs)
                .coordinateSpace(name: gameCoordinateSpace)
                .frame(width: geo.size.width, height: geo.size.height)
                .onPreferenceChange(CardFramePreferenceKey.self) { cardFrames = $0 }
                .onPreferenceChange(PileFramePreferenceKey.self) { pileFrame = $0 }
                .onPreferenceChange(HandCenterPreferenceKey.self) { handCenterFrames = $0 }
            }
        }
        .onChange(of: engine.lastEvent) { _, event in
            handle(event)
        }
        .onChange(of: engine.state.currentPlayerIndex) { _, _ in
            restartTurnPulse()
        }
        .onChange(of: engine.state.turnNumber) { _, _ in
            triggerAI()
        }
        .onAppear {
            restartTurnPulse()
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

    @ViewBuilder
    private var phaseContent: some View {
        switch engine.state.phase {
        case .dealing:
            StartScreenView(
                playerCount: $playerCount,
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
                burnEffect: burnEffect,
                wildEffect: wildEffect,
                turnPulse: turnPulse,
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

    private func startGame() {
        selectedCards.removeAll()
        activeFlights.removeAll()
        inFlightCardIDs.removeAll()
        dealRevealed = false
        withAnimation(springAnim) {
            engine.startNewGame(playerCount: playerCount, difficulty: difficulty)
        }
    }

    private func confirmSwap() {
        swapSelection = nil
        dealRevealed = false
        withAnimation(springAnim) {
            engine.confirmSwap()
        }
        restartTurnPulse()
        triggerAI()
    }

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
            withAnimation(springAnim) {
                engine.swapCards(handIndex: h, faceUpIndex: f)
            }
            swapSelection = nil
        case (.faceUp(let f), .hand(let h)):
            withAnimation(springAnim) {
                engine.swapCards(handIndex: h, faceUpIndex: f)
            }
            swapSelection = nil
        default:
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                swapSelection = current == tapped ? nil : tapped
            }
        }
    }

    private func pickUpPile() {
        selectedCards.removeAll()
        let pre = snapshot()
        withAnimation(springAnim) {
            engine.pickUpPile()
        }
        spawnFlights(computeFlights(pre: pre, post: snapshot()))
        triggerAI()
    }

    private func playFaceDownCard(at index: Int) {
        let pre = snapshot()
        withAnimation(springAnim) {
            engine.playFaceDownAt(index: index)
        }
        spawnFlights(computeFlights(pre: pre, post: snapshot()))
        triggerAI()
    }

    private func handleCardTap(_ card: Card) {
        guard engine.canPlay(card) else { return }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            toggleSelection(for: card)
        }
    }

    private func handleCardDoubleTap(_ card: Card) {
        guard engine.canPlay(card) else { return }

        if selectedCards.isEmpty || selectedCards[0].rank != card.rank {
            selectedCards = [card]
        } else if !selectedCards.contains(card) {
            selectedCards.append(card)
        }
        playSelectedCards()
    }

    private func beginCardDrag(_ card: Card) {
        guard engine.canPlay(card) else { return }

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

    private func playSelectedCards() {
        let pre = snapshot()
        withAnimation(springAnim) {
            engine.playCards(selectedCards)
            selectedCards.removeAll()
        }
        spawnFlights(computeFlights(pre: pre, post: snapshot()))
        triggerAI()
    }

    private func handle(_ event: GameEvent) {
        switch event {
        case .burn:
            triggerBurnEffect()
            SoundManager.play(.burn)
        case .wild:
            triggerWildEffect()
        case .pickup, .failedFlip:
            SoundManager.play(.pickup)
        case .skip:
            if !engine.state.currentPlayer.isAI {
                SoundManager.play(.skipped)
            }
        case .none, .normal, .sevenPlayed, .reverse:
            break
        }
    }

    private func triggerAI() {
        aiTask?.cancel()
        guard engine.state.phase == .playing,
              !engine.state.players.isEmpty,
              engine.state.currentPlayer.isAI
        else { return }

        let humanOut = !(humanPlayer?.hasCards ?? false)
        let delayMs = humanOut ? 300 : 800

        aiTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMs))
            guard !Task.isCancelled,
                  engine.state.phase == .playing,
                  engine.state.currentPlayer.isAI
            else { return }
            let pre = snapshot()
            withAnimation(springAnim) {
                engine.performAITurn()
            }
            spawnFlights(computeFlights(pre: pre, post: snapshot()))
        }
    }

    private struct StateSnapshot {
        let players: [Player]
        let pile: [Card]
    }

    private func snapshot() -> StateSnapshot {
        StateSnapshot(players: engine.state.players, pile: engine.state.pile)
    }

    private func spawnFlights(_ flights: [CardFlight]) {
        guard !flights.isEmpty else { return }
        inFlightCardIDs.formUnion(flights.map { $0.id })
        activeFlights.append(contentsOf: flights)
    }

    private func handleFlightComplete(_ id: UUID) {
        inFlightCardIDs.remove(id)
        activeFlights.removeAll { $0.id == id }
    }

    private func computeFlights(pre: StateSnapshot, post: StateSnapshot) -> [CardFlight] {
        guard pileFrame != .zero else { return [] }

        var flights: [CardFlight] = []
        var playStagger: Int = 0
        var pickupStaggerByPlayer: [String: Int] = [:]

        let postPileSet = Set(post.pile.map { $0.uid })
        let prePileSet = Set(pre.pile.map { $0.uid })

        for (playerIndex, postPlayer) in post.players.enumerated() {
            guard playerIndex < pre.players.count else { continue }
            let prePlayer = pre.players[playerIndex]
            let isAI = prePlayer.isAI

            let postHandSet = Set(postPlayer.hand.map { $0.uid })
            let postFaceUpSet = Set(postPlayer.faceUp.map { $0.uid })
            let postFaceDownSet = Set(postPlayer.faceDown.map { $0.uid })

            // Plays from hand → pile
            for card in prePlayer.hand
            where !postHandSet.contains(card.uid) && postPileSet.contains(card.uid) {
                guard let from = cardFrames[card.uid] else { continue }
                flights.append(CardFlight(
                    id: card.uid,
                    card: card,
                    from: from,
                    to: pileFrame,
                    startsFaceUp: !isAI,
                    endsFaceUp: true,
                    startDelay: TimeInterval(playStagger) * playStaggerSeconds,
                    duration: playFlightDuration
                ))
                playStagger += 1
            }

            // Plays from face-up → pile
            for card in prePlayer.faceUp
            where !postFaceUpSet.contains(card.uid) && postPileSet.contains(card.uid) {
                guard let from = cardFrames[card.uid] else { continue }
                flights.append(CardFlight(
                    id: card.uid,
                    card: card,
                    from: from,
                    to: pileFrame,
                    startsFaceUp: true,
                    endsFaceUp: true,
                    startDelay: TimeInterval(playStagger) * playStaggerSeconds,
                    duration: playFlightDuration
                ))
                playStagger += 1
            }

            // Plays from face-down → pile
            for card in prePlayer.faceDown
            where !postFaceDownSet.contains(card.uid) && postPileSet.contains(card.uid) {
                guard let from = cardFrames[card.uid] else { continue }
                flights.append(CardFlight(
                    id: card.uid,
                    card: card,
                    from: from,
                    to: pileFrame,
                    startsFaceUp: false,
                    endsFaceUp: true,
                    startDelay: TimeInterval(playStagger) * playStaggerSeconds,
                    duration: playFlightDuration
                ))
                playStagger += 1
            }

            // Pickups: pile cards that ended up in this player's hand
            let preHandSet = Set(prePlayer.hand.map { $0.uid })
            let pickedUp = postPlayer.hand.filter {
                !preHandSet.contains($0.uid) && prePileSet.contains($0.uid)
            }
            if !pickedUp.isEmpty, let to = handCenterFrames[postPlayer.id] {
                for card in pickedUp {
                    let stagger = pickupStaggerByPlayer[postPlayer.id, default: 0]
                    pickupStaggerByPlayer[postPlayer.id] = stagger + 1
                    flights.append(CardFlight(
                        id: card.uid,
                        card: card,
                        from: pileFrame,
                        to: to,
                        startsFaceUp: true,
                        endsFaceUp: !isAI,
                        startDelay: TimeInterval(stagger) * pickupStaggerSeconds,
                        duration: pickupFlightDuration
                    ))
                }
            }
        }

        return flights
    }

    private func triggerBurnEffect() {
        withAnimation(.easeOut(duration: 0.6)) {
            burnEffect = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            burnEffect = false
        }
    }

    private func triggerWildEffect() {
        withAnimation(.easeOut(duration: 0.15)) {
            wildEffect = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.15)) {
                wildEffect = false
            }
        }
    }

    private func restartTurnPulse() {
        turnPulse = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            turnPulse = true
        }
    }
}

#Preview {
    ContentView()
}
