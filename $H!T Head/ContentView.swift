import SwiftUI

struct ContentView: View {
    @State private var engine = GameEngine()
    @State private var selectedCards: [Card] = []
    @State private var playerCount: Int = 2

    // Visual-only state
    @State private var burnEffect = false
    @State private var resetEffect = false
    @State private var turnPulse = false

    private let springAnim = Animation.spring(response: 0.4, dampingFraction: 0.75)

    var body: some View {
        ZStack {
            tableBackground
                .ignoresSafeArea()

            if engine.state.phase == .dealing {
                startScreen
            } else {
                gameTable
                    .onChange(of: engine.lastPileClearReason) { _, reason in
                        switch reason {
                        case .burn: triggerBurnEffect()
                        case .none, .pickup, .failedFlip: break
                        }
                    }
                    .onChange(of: engine.message) { _, msg in
                        if msg.contains("reset") {
                            triggerResetEffect()
                        }
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
            }
        }
    }

    // MARK: - Table Background

    private var tableBackground: some View {
        FeltTableBackground()
    }

    // MARK: - Start Screen

    private var startScreen: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("$H!T HEAD")
                    .font(.system(size: 36, weight: .black, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                Text("Don't be the last one holding cards.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            VStack(spacing: 10) {
                Text("Players")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 10) {
                    ForEach(2...6, id: \.self) { count in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                playerCount = count
                            }
                        } label: {
                            Text("\(count)")
                                .font(.title3.bold())
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(playerCount == count
                                              ? Color.white.opacity(0.25)
                                              : Color.white.opacity(0.08))
                                )
                                .foregroundStyle(.white)
                        }
                    }
                }
                Text(deckLabel)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Button {
                selectedCards.removeAll()
                withAnimation(springAnim) {
                    engine.startNewGame(playerCount: playerCount)
                }
            } label: {
                Text("Deal")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 140, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 0.2, green: 0.5, blue: 0.3))
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    )
            }
        }
    }

    private var deckLabel: String {
        if playerCount <= 2 { return "1 deck \u{2022} 52 cards" }
        if playerCount <= 4 { return "2 decks \u{2022} 104 cards" }
        return "3 decks \u{2022} 156 cards"
    }

    // MARK: - Opponent Distribution

    private var opponents: [Player] {
        engine.state.players.filter { $0.isAI }
    }

    private var topOpponents: [Player] {
        let ops = opponents
        switch ops.count {
        case 1: return ops
        case 2: return ops
        case 3: return [ops[1]]
        case 4: return [ops[1], ops[2]]
        case 5: return [ops[1], ops[2], ops[3]]
        default: return ops
        }
    }

    private var leftOpponent: Player? {
        opponents.count >= 3 ? opponents[0] : nil
    }

    private var rightOpponent: Player? {
        opponents.count >= 3 ? opponents.last : nil
    }

    // MARK: - Game Table

    private var gameTable: some View {
        VStack(spacing: 0) {
            if !topOpponents.isEmpty {
                topOpponentsRow
                    .padding(.bottom, 4)
            }

            HStack(spacing: 0) {
                if let left = leftOpponent {
                    sideOpponentView(left)
                }

                Spacer(minLength: 0)

                VStack(spacing: 2) {
                    Spacer(minLength: 0)
                    centerArea
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                if let right = rightOpponent {
                    sideOpponentView(right)
                }
            }

            playerArea
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Top Opponents

    private var topOpponentsRow: some View {
        HStack(spacing: 6) {
            ForEach(topOpponents) { ai in
                topOpponentView(ai)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 4)
    }

    private func topOpponentView(_ ai: Player) -> some View {
        let active = isCurrentPlayer(ai)

        return VStack(spacing: 2) {
            HStack(spacing: 3) {
                Circle()
                    .fill(active ? .green : .gray)
                    .frame(width: 6, height: 6)
                    .opacity(active && turnPulse ? 1 : 0.4)
                Text(ai.name)
                    .font(.system(size: 10, weight: .bold))
                if !ai.hasCards {
                    Text("OUT")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(.green)
                }
                Spacer()
                Text("\(ai.hand.count)h \(ai.drawPile.count)d")
                    .font(.system(size: 8, design: .monospaced))
            }
            .foregroundStyle(.white.opacity(active ? 0.9 : 0.5))

            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    ZStack {
                        if i < ai.faceDown.count {
                            miniCard(faceUp: false)
                        }
                        if i < ai.faceUp.count {
                            miniCard(card: ai.faceUp[i])
                                .offset(y: -3)
                        }
                    }
                }
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(active ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(active ? Color.green.opacity(0.3) : .clear, lineWidth: 1)
                )
        )
        .scaleEffect(active ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: active)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Side Opponents

    private func sideOpponentView(_ ai: Player) -> some View {
        let active = isCurrentPlayer(ai)

        return VStack(spacing: 3) {
            Text(ai.name)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(active ? 0.9 : 0.5))

            Circle()
                .fill(active ? .green : .gray)
                .frame(width: 5, height: 5)
                .opacity(active && turnPulse ? 1 : 0.3)

            if !ai.hasCards {
                Text("OUT")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 1) {
                ForEach(0..<3, id: \.self) { i in
                    ZStack {
                        if i < ai.faceDown.count {
                            miniCard(faceUp: false)
                        }
                        if i < ai.faceUp.count {
                            miniCard(card: ai.faceUp[i])
                        }
                    }
                }
            }

            VStack(spacing: 0) {
                Text("\(ai.hand.count)h")
                Text("\(ai.drawPile.count)d")
            }
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(.white.opacity(0.4))
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(active ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(active ? Color.green.opacity(0.3) : .clear, lineWidth: 1)
                )
        )
        .scaleEffect(active ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: active)
        .frame(width: 46)
    }

    // MARK: - Mini Card

    private func miniCard(card: Card? = nil, faceUp: Bool = true) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(faceUp ? Color(white: 0.95) : Color(red: 0.12, green: 0.18, blue: 0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            if let card = card {
                HStack(spacing: 1) {
                    Text(card.rank.label)
                        .font(.system(size: 8, weight: .bold, design: .serif))
                    Text(suitChar(card.suit))
                        .font(.system(size: 7))
                }
                .foregroundStyle(card.suit == .hearts || card.suit == .diamonds
                                 ? Color(red: 0.8, green: 0.1, blue: 0.1)
                                 : Color(red: 0.1, green: 0.1, blue: 0.15))
            }
        }
        .frame(width: 24, height: 18)
    }

    private func suitChar(_ suit: Suit) -> String {
        switch suit {
        case .hearts: return "\u{2665}"
        case .diamonds: return "\u{2666}"
        case .clubs: return "\u{2663}"
        case .spades: return "\u{2660}"
        }
    }

    // MARK: - Center Area

    private var centerArea: some View {
        VStack(spacing: 4) {
            Text(engine.message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .frame(minHeight: 24)
                .padding(.horizontal)
                .animation(.easeInOut(duration: 0.2), value: engine.message)

            // Pile with effects
            ZStack {
                // Pile area
                VStack(spacing: 2) {
                    PileLandingZone(
                        topCard: engine.state.topCard,
                        pileCount: engine.state.pile.count
                    )

                    Text("Pile: \(engine.state.pile.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))

                    Text(ruleStatusText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(ruleStatusColor))
                        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                }

                // Burn effect
                if burnEffect {
                    burnOverlay
                }

                // Reset effect
                if resetEffect {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .transition(.opacity)
                }
            }

            actionButtons
        }
    }

    private var burnOverlay: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.orange.opacity(0.7))
                    .frame(width: 20, height: 30)
                    .offset(
                        x: cos(Double(i) * .pi / 4) * 70,
                        y: sin(Double(i) * .pi / 4) * 70
                    )
                    .rotationEffect(.degrees(Double(i) * 45 + 20))
                    .opacity(0)
            }
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.orange.opacity(0.6), .red.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(burnEffect ? 1.5 : 0.3)
                .opacity(burnEffect ? 0 : 1)
        }
        .transition(.opacity)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if engine.state.phase == .playing && !engine.state.currentPlayer.isAI {
                if !engine.hasPlayableCard(for: engine.state.currentPlayer) || !engine.state.pile.isEmpty {
                    Button {
                        selectedCards.removeAll()
                        withAnimation(springAnim) {
                            engine.pickUpPile()
                        }
                        triggerAI()
                    } label: {
                        Text("Pick Up Pile")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.7))
                                    .shadow(color: .red.opacity(0.3), radius: 4, y: 2)
                            )
                    }
                    .disabled(engine.state.pile.isEmpty && engine.hasPlayableCard(for: engine.state.currentPlayer))
                }
            }

            if engine.state.phase == .finished {
                Button {
                    selectedCards.removeAll()
                    withAnimation(springAnim) {
                        engine.startNewGame(playerCount: playerCount)
                    }
                } label: {
                    Text("Play Again")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.2, green: 0.5, blue: 0.3))
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        )
                }
            }
        }
    }

    // MARK: - Player Area

    private var playerArea: some View {
        let human = engine.state.players.first(where: { !$0.isAI })!
        let isMyTurn = !engine.state.currentPlayer.isAI && engine.state.phase == .playing

        return VStack(spacing: 2) {
            // Table cards
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    ZStack {
                        if i < human.faceDown.count {
                            CardView(card: human.faceDown[i], faceUp: false, small: true)
                        }
                        if i < human.faceUp.count {
                            CardView(card: human.faceUp[i], faceUp: true, small: true)
                                .offset(y: -5)
                        }
                    }
                    .onTapGesture {
                        tapTableCard(index: i, player: human, isMyTurn: isMyTurn)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }

            HStack {
                Text("Hand (\(human.hand.count))")
                    .font(.system(size: 10, weight: .bold))
                Spacer()
                Text("Draw: \(human.drawPile.count)")
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 8)

            // Fan hand
            fanHand(human: human, isMyTurn: isMyTurn)
                .padding(.horizontal, 4)

            if isMyTurn && !selectedCards.isEmpty {
                selectionControls
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isMyTurn ? 0.06 : 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isMyTurn
                                ? Color.green.opacity(turnPulse ? 0.4 : 0.15)
                                : .clear,
                            lineWidth: 1.5
                        )
                )
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: turnPulse)
        )
        .padding(.horizontal, 4)
    }

    private func fanHand(human: Player, isMyTurn: Bool) -> some View {
        let count = human.hand.count
        let maxSpread: Double = min(Double(count - 1) * 4.0, 28)

        return GeometryReader { geo in
            let availableWidth = geo.size.width
            let cardWidth: CGFloat = 56
            let totalFanWidth = min(availableWidth, CGFloat(count) * 32)
            let xStep = count > 1 ? totalFanWidth / CGFloat(count - 1) : 0
            let startX = (availableWidth - totalFanWidth) / 2

            ZStack {
                ForEach(Array(human.hand.enumerated()), id: \.element.id) { index, card in
                    let progress = count > 1 ? Double(index) / Double(count - 1) : 0.5
                    let angle = (progress - 0.5) * maxSpread
                    let normalizedDist = abs(progress - 0.5)
                    let yOffset = normalizedDist * normalizedDist * 12

                    let playable = isMyTurn && engine.canPlay(card)
                    let isSelected = selectedCards.contains(card)

                    CardView(
                        card: card,
                        faceUp: true,
                        highlight: playable && !isSelected,
                        selected: isSelected,
                        dimmed: !isMyTurn
                    )
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .offset(y: yOffset)
                    .position(
                        x: startX + CGFloat(index) * xStep + cardWidth / 2,
                        y: geo.size.height / 2
                    )
                    .zIndex(isSelected ? 100 : Double(index))
                    .onTapGesture {
                        guard isMyTurn else { return }
                        handleCardTap(card)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
            }
        }
        .frame(height: 105)
    }

    // MARK: - Helpers

    private func isCurrentPlayer(_ player: Player) -> Bool {
        engine.state.currentPlayerIndex < engine.state.players.count
            && engine.state.players[engine.state.currentPlayerIndex].id == player.id
    }

    private func tapTableCard(index: Int, player: Player, isMyTurn: Bool) {
        guard isMyTurn else { return }
        guard player.hand.isEmpty, player.drawPile.isEmpty else { return }

        if player.faceUp.isEmpty {
            if index < player.faceDown.count {
                withAnimation(springAnim) {
                    engine.playFaceDownAt(index: index)
                }
                triggerAI()
            }
        } else {
            if index < player.faceUp.count {
                withAnimation(springAnim) {
                    engine.playCard(player.faceUp[index])
                }
                triggerAI()
            }
        }
    }

    private func handleCardTap(_ card: Card) {
        guard engine.canPlay(card) else { return }

        if selectedCards.contains(card) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedCards.removeAll { $0 == card }
            }
        } else if selectedCards.isEmpty {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedCards.append(card)
            }
        } else if card.rank == selectedCards[0].rank {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedCards.append(card)
            }
        } else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedCards = [card]
            }
        }
    }

    private var selectionControls: some View {
        HStack(spacing: 10) {
            Button("Clear") {
                withAnimation(springAnim) { selectedCards.removeAll() }
            }
            .font(.caption.bold())
            .foregroundStyle(.white.opacity(0.72))

            Button(action: playSelectedCards) {
                Text("Play \(selectedCards.count) \(selectedCards[0].rank.label)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.green.opacity(0.75)))
            }
        }
        .padding(.bottom, 4)
    }

    private func playSelectedCards() {
        withAnimation(springAnim) {
            engine.playCards(selectedCards)
            selectedCards.removeAll()
        }
        triggerAI()
    }

    private var ruleStatusText: String {
        if engine.mustPlayUnderSeven { return "Play 7 or lower" }
        guard let topCard = engine.state.effectiveTopCard else { return "Any card" }
        return "Play \(topCard.rank.label) or higher"
    }

    private var ruleStatusColor: Color {
        if engine.mustPlayUnderSeven { return Color.orange.opacity(0.72) }
        if engine.state.pile.isEmpty { return Color.green.opacity(0.42) }
        return Color.black.opacity(0.24)
    }

    private func triggerAI() {
        guard engine.state.currentPlayer.isAI && engine.state.phase == .playing else { return }

        let expectedTurn = engine.state.turnNumber
        let expectedPlayer = engine.state.currentPlayerIndex
        let humanOut = !(engine.state.players.first(where: { !$0.isAI })?.hasCards ?? false)
        let delay: Double = humanOut ? 0.3 : 0.8

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard engine.state.phase == .playing,
                  engine.state.turnNumber == expectedTurn,
                  engine.state.currentPlayerIndex == expectedPlayer
            else { return }
            withAnimation(springAnim) {
                engine.performAITurn()
            }
        }
    }

    // MARK: - Effects

    private func triggerBurnEffect() {
        withAnimation(.easeOut(duration: 0.6)) {
            burnEffect = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            burnEffect = false
        }
    }

    private func triggerResetEffect() {
        withAnimation(.easeOut(duration: 0.15)) {
            resetEffect = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.15)) {
                resetEffect = false
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
