import Foundation

enum PileClearReason {
    case none, burn, pickup, failedFlip
}

@Observable
class GameEngine {
    var state = GameState()
    var message: String = ""
    var mustPlayUnderSeven: Bool = false
    var lastPileClearReason: PileClearReason = .none

    // MARK: - Setup

    func startNewGame(playerCount: Int = 2) {
        state = GameState()
        let clamped = min(max(playerCount, 2), 6)

        let deckCount: Int
        if clamped <= 2 {
            deckCount = 1
        } else if clamped <= 4 {
            deckCount = 2
        } else {
            deckCount = 3
        }
        state.deck = Deck.standard(deckCount: deckCount)

        let aiNames = ["CPU 1", "CPU 2", "CPU 3", "CPU 4", "CPU 5"]
        var players: [Player] = [Player(id: "human", name: "You", isAI: false)]
        for i in 0..<(clamped - 1) {
            players.append(Player(id: "ai\(i)", name: aiNames[i], isAI: true))
        }
        state.players = players

        deal()
    }

    private func deal() {
        for i in state.players.indices {
            state.players[i].faceDown = state.deck.draw(3)
            state.players[i].faceUp = state.deck.draw(3)
        }

        var playerIndex = 0
        while let card = state.deck.draw() {
            state.players[playerIndex].drawPile.append(card)
            playerIndex = (playerIndex + 1) % state.players.count
        }

        for i in state.players.indices {
            refillHand(playerIndex: i)
        }

        state.phase = .playing
        state.currentPlayerIndex = 0
        message = "Your turn"
    }

    // MARK: - Move Validation

    func canPlay(_ card: Card) -> Bool {
        if card.isReset || card.isBurn { return true }

        if mustPlayUnderSeven {
            return card.rank <= .seven
        }

        guard let top = state.effectiveTopCard else { return true }

        return card.rank >= top.rank
    }

    func playableCards(for player: Player) -> [Card] {
        player.activeCards.filter { canPlay($0) }
    }

    func hasPlayableCard(for player: Player) -> Bool {
        !playableCards(for: player).isEmpty
    }

    // MARK: - Playing Cards

    func playCards(_ cards: [Card]) {
        guard state.phase == .playing else { return }
        guard !cards.isEmpty else { return }
        guard cards.allSatisfy({ $0.rank == cards[0].rank }) else { return }
        guard canPlay(cards[0]) else { return }

        let playerIndex = state.currentPlayerIndex
        var player = state.players[playerIndex]
        let zone = player.playingFrom

        // Validate all cards exist in the active zone
        let activeCards: [Card]
        switch zone {
        case .hand: activeCards = player.hand
        case .faceUp: activeCards = player.faceUp
        case .faceDown: activeCards = player.faceDown
        }
        for card in cards {
            guard activeCards.contains(card) else { return }
        }

        for card in cards {
            removeCard(card, from: &player, zone: zone)
        }
        state.pile.append(contentsOf: cards)
        state.players[playerIndex] = player

        refillHand(playerIndex: playerIndex)
        afterPlay(card: cards[0], playerIndex: playerIndex)
    }

    func playCard(_ card: Card) {
        playCards([card])
    }

    func playFaceDownAt(index: Int) {
        guard state.phase == .playing else { return }
        let playerIndex = state.currentPlayerIndex
        guard index < state.players[playerIndex].faceDown.count else { return }

        let card = state.players[playerIndex].faceDown[index]
        state.players[playerIndex].faceDown.remove(at: index)

        if canPlay(card) {
            state.pile.append(card)
            afterPlay(card: card, playerIndex: playerIndex)
        } else {
            state.players[playerIndex].hand.append(card)
            state.players[playerIndex].hand.append(contentsOf: state.pile)
            state.pile.removeAll()
            lastPileClearReason = .failedFlip
            mustPlayUnderSeven = false
            message = "\(state.players[playerIndex].name) flipped \(card.display) — picked up the pile!"
            advanceTurn()
        }
    }

    private func removeCard(_ card: Card, from player: inout Player, zone: CardZone) {
        switch zone {
        case .hand:
            if let idx = player.hand.firstIndex(of: card) {
                player.hand.remove(at: idx)
            }
        case .faceUp:
            if let idx = player.faceUp.firstIndex(of: card) {
                player.faceUp.remove(at: idx)
            }
        case .faceDown:
            if let idx = player.faceDown.firstIndex(of: card) {
                player.faceDown.remove(at: idx)
            }
        }
    }

    private func refillHand(playerIndex: Int) {
        while state.players[playerIndex].hand.count < 3,
              !state.players[playerIndex].drawPile.isEmpty {
            let card = state.players[playerIndex].drawPile.removeFirst()
            state.players[playerIndex].hand.append(card)
        }
    }

    // MARK: - After Play Logic

    private func afterPlay(card: Card, playerIndex: Int) {
        if checkForBurn(card: card, playerIndex: playerIndex) {
            return
        }

        if checkWin(playerIndex: playerIndex) {
            return
        }

        mustPlayUnderSeven = card.isSeven

        if card.isBurn {
            burnPile(playerIndex: playerIndex)
            return
        }

        if card.isReverse {
            state.playDirection *= -1
            message = "\(state.players[playerIndex].name) played \(card.display) — reversed!"
        } else if card.isReset {
            message = "\(state.players[playerIndex].name) played \(card.display) — pile reset!"
        } else if card.isSkip {
            message = "\(state.players[playerIndex].name) played \(card.display) — skip!"
            advanceTurn(skip: true)
            return
        } else {
            message = "\(state.players[playerIndex].name) played \(card.display)"
        }

        advanceTurn()
    }

    private func checkForBurn(card: Card, playerIndex: Int) -> Bool {
        guard pile.count >= 4 else { return false }
        let topFour = pile.suffix(4)
        let allSameRank = topFour.allSatisfy { $0.rank == card.rank }
        if allSameRank {
            message = "Four \(card.rank.label)s — pile burned!"
            burnPile(playerIndex: playerIndex)
            return true
        }
        return false
    }

    private var pile: [Card] { state.pile }

    private func burnPile(playerIndex: Int) {
        state.pile.removeAll()
        lastPileClearReason = .burn
        mustPlayUnderSeven = false

        if checkWin(playerIndex: playerIndex) { return }

        state.currentPlayerIndex = playerIndex
        state.turnNumber += 1
        if message.isEmpty {
            message = "\(state.players[playerIndex].name) burned the pile!"
        }
        message += " Goes again."
    }

    // MARK: - Pick Up Pile

    func pickUpPile() {
        guard state.phase == .playing else { return }
        let playerIndex = state.currentPlayerIndex
        state.players[playerIndex].hand.append(contentsOf: state.pile)
        state.pile.removeAll()
        lastPileClearReason = .pickup
        mustPlayUnderSeven = false
        message = "\(state.players[playerIndex].name) picked up the pile"
        advanceTurn()
    }

    // MARK: - Turn Management

    private func advanceTurn(skip: Bool = false) {
        if checkGameOver() { return }

        let count = state.players.count
        let steps = skip ? 2 : 1
        var nextIndex = ((state.currentPlayerIndex + state.playDirection * steps) % count + count) % count

        var attempts = 0
        while !state.players[nextIndex].hasCards && attempts < count {
            nextIndex = ((nextIndex + state.playDirection) % count + count) % count
            attempts += 1
        }

        state.currentPlayerIndex = nextIndex
        state.turnNumber += 1

        if !state.currentPlayer.isAI {
            message += " — Your turn"
        }
    }

    // MARK: - Win / Loss

    private func checkWin(playerIndex: Int) -> Bool {
        if !state.players[playerIndex].hasCards {
            if checkGameOver() { return true }
        }
        return false
    }

    private func checkGameOver() -> Bool {
        let activePlayers = state.players.filter { $0.hasCards }
        if activePlayers.count <= 1 {
            state.phase = .finished
            if let loser = activePlayers.first {
                message = "\(loser.name) is the Sh*t Head!"
            } else {
                message = "Game over — it's a tie!"
            }
            return true
        }
        return false
    }

    // MARK: - AI

    func performAITurn() {
        let player = state.currentPlayer

        if player.playingFrom == .faceDown {
            let randomIndex = Int.random(in: 0..<player.faceDown.count)
            playFaceDownAt(index: randomIndex)
            return
        }

        let playable = playableCards(for: player)
        if let card = playable.sorted(by: { $0.rank < $1.rank }).first {
            let matching = playable.filter { $0.rank == card.rank }
            playCards(matching)
        } else {
            pickUpPile()
        }
    }
}
