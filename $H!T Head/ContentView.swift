import SwiftUI

struct ContentView: View {
    @State private var engine = GameEngine()
    @State private var selectedCards: [Card] = []
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
    @State private var drawPileFrames: [String: CGRect] = [:]
    @State private var inFlightCardIDs: Set<UUID> = []
    @State private var activeFlights: [CardFlight] = []

    @State private var lastPileSnapshot: [Card] = []
    @State private var pendingBurnPile: [Card] = []
    @State private var burnedCards: [Card] = []
    @State private var burnFlyProgress: CGFloat = 0

    @State private var revealedFaceDownIndex: Int? = nil

    @State private var rejectionShakeID: UUID? = nil
    @State private var rejectionShakeTrigger: CGFloat = 0
    @State private var rejectionMessage: String? = nil
    @State private var rejectionMessageTask: Task<Void, Never>?

    @Namespace private var swapNamespace

    private let springAnim = Animation.spring(response: 0.4, dampingFraction: 0.75)
    private let playStaggerSeconds: TimeInterval = 0.085
    private let pickupStaggerSeconds: TimeInterval = 0.05
    private let playFlightDuration: TimeInterval = 0.45
    private let pickupFlightDuration: TimeInterval = 0.4
    private let drawFlightDuration: TimeInterval = 0.4
    private let drawStaggerSeconds: TimeInterval = 0.1
    private let aiFlightLayoutDelay: Duration = .milliseconds(30)
    private let rejectionShakeDuration: TimeInterval = 0.45
    private let rejectionMessageDuration: TimeInterval = 1.5

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

                    ForEach(Array(burnedCards.enumerated()), id: \.element.uid) { index, card in
                        let scatter = CGFloat(index) * 0.15
                        CardView(card: card, faceUp: true)
                            .allowsHitTesting(false)
                            .position(
                                x: pileFrame.midX + burnFlyProgress * (400 + CGFloat(index) * 25),
                                y: pileFrame.midY - burnFlyProgress * (600 + CGFloat(index) * 15)
                            )
                            .rotationEffect(.degrees(burnFlyProgress * (35 + Double(index) * 12)))
                            .scaleEffect(0.85 - burnFlyProgress * 0.25 + scatter * 0.1)
                            .opacity(max(0, 1 - burnFlyProgress * 1.6))
                            .zIndex(300)
                    }
                }
                .environment(\.gameScale, scale)
                .environment(\.inFlightCardIDs, inFlightCardIDs)
                .environment(\.rejectionShakeID, rejectionShakeID)
                .environment(\.rejectionShakeTrigger, rejectionShakeTrigger)
                .coordinateSpace(name: gameCoordinateSpace)
                .frame(width: geo.size.width, height: geo.size.height)
                .onPreferenceChange(CardFramePreferenceKey.self) { cardFrames = $0 }
                .onPreferenceChange(PileFramePreferenceKey.self) { pileFrame = $0 }
                .onPreferenceChange(HandCenterPreferenceKey.self) { handCenterFrames = $0 }
                .onPreferenceChange(DrawPileFramePreferenceKey.self) { drawPileFrames = $0 }
            }
        }
        .overlay(alignment: .top) {
            if let message = rejectionMessage {
                RejectionTooltip(message: message)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: engine.eventSerial) { _, _ in
            handle(engine.lastEvent)
        }
        .onChange(of: engine.state.currentPlayerIndex) { _, _ in
            restartTurnPulse()
        }
        .onChange(of: engine.state.turnNumber) { _, _ in
            triggerAI()
        }
        .onChange(of: engine.state.phase) { _, phase in
            if phase == .finished {
                clearFlightsAfterAnimationsSettle()
            }
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
                revealedFaceDownIndex: revealedFaceDownIndex,
                pendingBurnPile: pendingBurnPile,
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
            engine.startNewGame(playerCount: 4, difficulty: difficulty)
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
        pendingBurnPile.removeAll()
        lastPileSnapshot = engine.state.pile
        let pre = snapshot()
        withAnimation(springAnim) {
            engine.pickUpPile()
        }
        spawnFlights(computeFlights(pre: pre, post: snapshot()))
        triggerAI()
    }

    private func playFaceDownCard(at index: Int) {
        guard revealedFaceDownIndex == nil else { return }

        revealedFaceDownIndex = index

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))

            revealedFaceDownIndex = nil
            pendingBurnPile.removeAll()
            lastPileSnapshot = engine.state.pile
            let pre = snapshot()
            withAnimation(springAnim) {
                engine.playFaceDownAt(index: index)
            }
            let post = snapshot()
            spawnFlights(computeFlights(pre: pre, post: post))
            setupPendingBurn(pre: pre, post: post)
            triggerAI()
        }
    }

    private func handleCardTap(_ card: Card) {
        guard engine.canPlay(card) else {
            triggerRejectionFeedback(for: card)
            return
        }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            toggleSelection(for: card)
        }
    }

    private func handleCardDoubleTap(_ card: Card) {
        guard engine.canPlay(card) else {
            triggerRejectionFeedback(for: card)
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
            triggerRejectionFeedback(for: card)
            return
        }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            if !selectedCards.contains(card) {
                selectOnlyCompatible(card)
            }
            dragCardID = card.id
        }
    }

    private func triggerRejectionFeedback(for card: Card) {
        guard engine.difficulty == .easy else { return }

        rejectionShakeID = card.uid
        rejectionShakeTrigger = 0
        withAnimation(.linear(duration: rejectionShakeDuration)) {
            rejectionShakeTrigger = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + rejectionShakeDuration + 0.05) {
            if rejectionShakeID == card.uid {
                rejectionShakeID = nil
                rejectionShakeTrigger = 0
            }
        }

        let reason = rejectionReason(for: card)
        rejectionMessageTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            rejectionMessage = reason
        }
        rejectionMessageTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(rejectionMessageDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.3)) {
                rejectionMessage = nil
            }
        }
    }

    private func rejectionReason(for card: Card) -> String {
        if engine.mustPlayUnderSeven {
            return "Must play 7 or lower — a 7 was played"
        }
        if let top = engine.state.effectiveTopCard {
            return "Must play \(top.rank.label) or higher (or a 2 / 10)"
        }
        return "Can't play that card right now"
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
        pendingBurnPile.removeAll()
        lastPileSnapshot = engine.state.pile
        let pre = snapshot()
        withAnimation(springAnim) {
            engine.playCards(selectedCards)
            selectedCards.removeAll()
        }
        let post = snapshot()
        spawnFlights(computeFlights(pre: pre, post: post))
        setupPendingBurn(pre: pre, post: post)
        triggerAI()
    }

    private func handle(_ event: GameEvent) {
        switch event {
        case .burn:
            let burnDelay = playFlightDuration + 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + burnDelay) {
                triggerBurnEffect()
                SoundManager.play(.burn)
            }
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
        let burnPending = !pendingBurnPile.isEmpty
        let delayMs = burnPending ? 1800 : (humanOut ? 300 : 800)

        aiTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMs))
            guard !Task.isCancelled,
                  engine.state.phase == .playing,
                  engine.state.currentPlayer.isAI
            else { return }

            pendingBurnPile.removeAll()
            lastPileSnapshot = engine.state.pile
            let pre = snapshot()
            withAnimation(springAnim) {
                engine.performAITurn()
            }
            let post = snapshot()
            spawnFlights(computeFlights(pre: pre, post: post))
            setupPendingBurn(pre: pre, post: post)
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

    private func setupPendingBurn(pre: StateSnapshot, post: StateSnapshot) {
        guard engine.lastEvent == .burn else { return }
        var allPostIDs = Set(post.pile.map { $0.uid })
        for p in post.players {
            allPostIDs.formUnion(p.hand.map { $0.uid })
            allPostIDs.formUnion(p.faceUp.map { $0.uid })
            allPostIDs.formUnion(p.faceDown.map { $0.uid })
            allPostIDs.formUnion(p.drawPile.map { $0.uid })
        }
        var playedCards: [Card] = []
        for (i, prePlayer) in pre.players.enumerated() {
            guard i < post.players.count else { continue }
            for card in prePlayer.hand {
                if !allPostIDs.contains(card.uid) { playedCards.append(card) }
            }
            for card in prePlayer.faceUp {
                if !allPostIDs.contains(card.uid) { playedCards.append(card) }
            }
            for card in prePlayer.faceDown {
                if !allPostIDs.contains(card.uid) { playedCards.append(card) }
            }
        }
        pendingBurnPile = lastPileSnapshot + playedCards
    }

    private func clearFlightsAfterAnimationsSettle() {
        let settleDelay = max(playFlightDuration, pickupFlightDuration) + 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) {
            guard engine.state.phase == .finished else { return }
            activeFlights.removeAll()
            inFlightCardIDs.removeAll()
        }
    }

    private func computeFlights(pre: StateSnapshot, post: StateSnapshot) -> [CardFlight] {
        guard pileFrame != .zero else { return [] }
        let scale = pileFrame.width / 82

        var flights: [CardFlight] = []
        var playStagger: Int = 0
        var pickupStaggerByPlayer: [String: Int] = [:]

        let postPileSet = Set(post.pile.map { $0.uid })
        let prePileSet = Set(pre.pile.map { $0.uid })

        var allPostIDs = Set(post.pile.map { $0.uid })
        for p in post.players {
            allPostIDs.formUnion(p.hand.map { $0.uid })
            allPostIDs.formUnion(p.faceUp.map { $0.uid })
            allPostIDs.formUnion(p.faceDown.map { $0.uid })
            allPostIDs.formUnion(p.drawPile.map { $0.uid })
        }

        for (playerIndex, postPlayer) in post.players.enumerated() {
            guard playerIndex < pre.players.count else { continue }
            let prePlayer = pre.players[playerIndex]
            let isAI = prePlayer.isAI

            let postHandSet = Set(postPlayer.hand.map { $0.uid })
            let postFaceUpSet = Set(postPlayer.faceUp.map { $0.uid })
            let postFaceDownSet = Set(postPlayer.faceDown.map { $0.uid })

            // Plays from hand → pile (or burned)
            for card in prePlayer.hand
            where !postHandSet.contains(card.uid) && (postPileSet.contains(card.uid) || !allPostIDs.contains(card.uid)) {
                guard let from = sourceFrame(for: card, player: prePlayer) else { continue }
                appendPlayFlight(
                    card: card,
                    from: from,
                    startsFaceUp: !isAI,
                    playStagger: &playStagger,
                    flights: &flights
                )
            }

            // Plays from face-up → pile (or burned)
            for card in prePlayer.faceUp
            where !postFaceUpSet.contains(card.uid) && (postPileSet.contains(card.uid) || !allPostIDs.contains(card.uid)) {
                guard let from = sourceFrame(for: card, player: prePlayer) else { continue }
                appendPlayFlight(
                    card: card,
                    from: from,
                    startsFaceUp: true,
                    playStagger: &playStagger,
                    flights: &flights
                )
            }

            // Plays from face-down → pile (or burned)
            for card in prePlayer.faceDown
            where !postFaceDownSet.contains(card.uid) && (postPileSet.contains(card.uid) || !allPostIDs.contains(card.uid)) {
                guard let from = sourceFrame(for: card, player: prePlayer) else { continue }
                appendPlayFlight(
                    card: card,
                    from: from,
                    startsFaceUp: false,
                    playStagger: &playStagger,
                    flights: &flights
                )
            }

            // Pickups: pile cards that ended up in this player's hand
            let preHandSet = Set(prePlayer.hand.map { $0.uid })
            let pickedUp = postPlayer.hand.filter {
                !preHandSet.contains($0.uid) && prePileSet.contains($0.uid)
            }

            if !pickedUp.isEmpty {
                let rawDest = handCenterFrames[postPlayer.id] ?? cardFrames[postPlayer.hand.first?.uid ?? UUID()]
                if let dest = rawDest {
                    let cardW: CGFloat = isAI ? 30 * scale : 58 * scale
                    let cardH: CGFloat = isAI ? 40 * scale : 82 * scale
                    let to = CGRect(
                        x: dest.midX - cardW / 2,
                        y: dest.midY - cardH / 2,
                        width: cardW,
                        height: cardH
                    )

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

            // Draws: draw pile cards that ended up in this player's hand
            let preDrawSet = Set(prePlayer.drawPile.map { $0.uid })
            let drawn = postPlayer.hand.filter {
                !preHandSet.contains($0.uid) && preDrawSet.contains($0.uid)
            }

            if !drawn.isEmpty, let drawFrom = drawPileFrames[postPlayer.id] {
                let rawDest = handCenterFrames[postPlayer.id] ?? cardFrames[postPlayer.hand.first?.uid ?? UUID()]
                if let dest = rawDest {
                    let cardW: CGFloat = isAI ? 30 * scale : 58 * scale
                    let cardH: CGFloat = isAI ? 40 * scale : 82 * scale
                    let to = CGRect(
                        x: dest.midX - cardW / 2,
                        y: dest.midY - cardH / 2,
                        width: cardW,
                        height: cardH
                    )

                    let playDelay = TimeInterval(playStagger) * playStaggerSeconds + playFlightDuration
                    for (drawIndex, card) in drawn.enumerated() {
                        flights.append(CardFlight(
                            id: card.uid,
                            card: card,
                            from: drawFrom,
                            to: to,
                            startsFaceUp: false,
                            endsFaceUp: !isAI,
                            startDelay: playDelay + TimeInterval(drawIndex) * drawStaggerSeconds,
                            duration: drawFlightDuration
                        ))
                    }
                }
            }
        }

        return flights
    }

    private func sourceFrame(for card: Card, player: Player) -> CGRect? {
        cardFrames[card.uid] ?? handCenterFrames[player.id]
    }

    private func appendPlayFlight(
        card: Card,
        from: CGRect,
        startsFaceUp: Bool,
        playStagger: inout Int,
        flights: inout [CardFlight]
    ) {
        flights.append(CardFlight(
            id: card.uid,
            card: card,
            from: from,
            to: pileFrame,
            startsFaceUp: startsFaceUp,
            endsFaceUp: true,
            startDelay: TimeInterval(playStagger) * playStaggerSeconds,
            duration: playFlightDuration
        ))
        playStagger += 1
    }

    private func triggerBurnEffect() {
        let flyOffCards = pendingBurnPile.isEmpty
            ? Array(lastPileSnapshot.suffix(4))
            : Array(pendingBurnPile.suffix(4))

        withAnimation(.easeOut(duration: 0.6)) {
            burnEffect = true
            pendingBurnPile.removeAll()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            burnEffect = false
        }

        burnedCards = flyOffCards
        burnFlyProgress = 0
        withAnimation(.easeIn(duration: 0.55)) {
            burnFlyProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            burnedCards.removeAll()
            burnFlyProgress = 0
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
