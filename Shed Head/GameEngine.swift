import Foundation

@MainActor
@Observable
class GameEngine {
    var state = GameState()
    var message: String = ""
    var mustPlayUnderSeven: Bool = false
    var lastEvent: GameEvent = .none
    var eventSerial: Int = 0
    var difficulty: Difficulty = .medium
    var openingCard: Card? = nil
    var skippedPlayerID: String? = nil
    var lastBurnWasFourOfAKind = false
    var pendingJokerPlayerIndex: Int? = nil
    var jokerTargetPlayerID: String? = nil

    // MARK: - Setup

    func startNewGame(playerCount: Int = 2, difficulty: Difficulty = .medium) {
        self.difficulty = difficulty
        eventSerial = 0
        lastEvent = .none
        mustPlayUnderSeven = false
        openingCard = nil
        skippedPlayerID = nil
        lastBurnWasFourOfAKind = false
        pendingJokerPlayerIndex = nil
        jokerTargetPlayerID = nil
        state = GameDealer.newGameState(playerCount: playerCount)
        message = "Swap cards between your hand and face-up cards"
    }

    func startTutorialGame(playerCount: Int = 4) {
        difficulty = .easy
        eventSerial = 0
        lastEvent = .none
        mustPlayUnderSeven = false
        openingCard = nil
        skippedPlayerID = nil
        lastBurnWasFourOfAKind = false
        pendingJokerPlayerIndex = nil
        jokerTargetPlayerID = nil
        state = GameDealer.newTutorialGameState(playerCount: playerCount)
        message = "Swap cards between your hand and face-up cards"
    }

    // MARK: - Swap Phase

    func swapCards(handIndex: Int, faceUpIndex: Int) {
        guard state.phase == .swapping else { return }
        guard let humanIndex = state.players.firstIndex(where: { !$0.isAI }) else { return }
        guard handIndex < state.players[humanIndex].hand.count else { return }
        guard faceUpIndex < state.players[humanIndex].faceUp.count else { return }

        let temp = state.players[humanIndex].hand[handIndex]
        state.players[humanIndex].hand[handIndex] = state.players[humanIndex].faceUp[faceUpIndex]
        state.players[humanIndex].faceUp[faceUpIndex] = temp
    }

    func confirmSwap() {
        guard state.phase == .swapping else { return }
        performAISwaps()
        let starter = determineStartingPlayer()
        state.phase = .playing
        state.currentPlayerIndex = starter
        state.turnNumber = 0
        if state.players[starter].isAI {
            message = "\(state.players[starter].name) has the lowest card — goes first!"
        } else {
            message = "You have the lowest card — your turn!"
        }
    }

    func forceHumanTutorialTurn() {
        guard let humanIndex = state.players.firstIndex(where: { !$0.isAI }) else { return }
        ensureHumanHasLowestTutorialStarter(humanIndex: humanIndex)
        openingCard = lowestNonWildCard(in: state.players[humanIndex].hand)
        mustPlayUnderSeven = false
        state.pile.removeAll()
        state.currentPlayerIndex = humanIndex
        state.turnNumber = 0
        message = "Your turn"
    }

    private func ensureHumanHasLowestTutorialStarter(humanIndex: Int) {
        guard let lowest = lowestNonWildCard(in: state.players[humanIndex].hand + state.players[humanIndex].faceUp),
              !state.players[humanIndex].hand.contains(lowest),
              let faceUpIndex = state.players[humanIndex].faceUp.firstIndex(of: lowest),
              let handSwapIndex = highestNonWildCardIndex(in: state.players[humanIndex].hand)
        else { return }

        let swapCard = state.players[humanIndex].hand[handSwapIndex]
        state.players[humanIndex].hand[handSwapIndex] = lowest
        state.players[humanIndex].faceUp[faceUpIndex] = swapCard
        state.players[humanIndex].hand = GameRules.sortPlayableOrder(state.players[humanIndex].hand)
    }

    private func lowestNonWildCard(in cards: [Card]) -> Card? {
        cards
            .filter { $0.rank != .two && $0.rank != .joker }
            .min { $0.rank < $1.rank }
    }

    private func highestNonWildCardIndex(in cards: [Card]) -> Int? {
        cards.indices
            .filter { cards[$0].rank != .two && cards[$0].rank != .joker }
            .max { cards[$0].rank < cards[$1].rank }
    }

    private func determineStartingPlayer() -> Int {
        let suitOrder: [Suit] = [.clubs, .diamonds, .spades, .hearts]
        for rank in Rank.allCases where rank != .two && rank != .joker {
            for suit in suitOrder {
                for (index, player) in state.players.enumerated() {
                    if let card = player.hand.first(where: { $0.rank == rank && $0.suit == suit }) {
                        openingCard = card
                        return index
                    }
                }
            }
        }
        return 0
    }

    private func performAISwaps() {
        AIPlayer.performSwaps(state: state, difficulty: difficulty)
    }

    // MARK: - Move Validation

    func canPlay(_ card: Card) -> Bool {
        GameRules.canPlay(card, effectiveTopCard: state.effectiveTopCard, mustPlayUnderSeven: mustPlayUnderSeven)
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

        if let required = openingCard {
            guard cards.contains(required) else { return }
        }

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

        GameDealer.refillHand(&state.players[playerIndex])
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
            state.players[playerIndex].hand = GameRules.sortPlayableOrder(state.players[playerIndex].hand)
            publishEvent(.failedFlip)
            mustPlayUnderSeven = false
            message = "\(state.players[playerIndex].name) flipped \(card.display) — picked up the pile!"
            advanceTurn()
        }
    }

    private func removeCard(_ card: Card, from player: inout Player, zone: CardZone) {
        var cards = player.cards(in: zone)
        if let idx = cards.firstIndex(of: card) {
            cards.remove(at: idx)
            player.setCards(cards, in: zone)
        }
    }

    // MARK: - After Play Logic

    private func afterPlay(card: Card, playerIndex: Int) {
        openingCard = nil
        lastBurnWasFourOfAKind = false

        if card.isJoker {
            handleJoker(card: card, playerIndex: playerIndex)
            return
        }

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
            publishEvent(.reverse)
            message = "\(state.players[playerIndex].name) played \(card.display) — reversed!"
        } else if card.isWild {
            publishEvent(.wild)
            message = "\(state.players[playerIndex].name) played \(card.display) — wild!"
        } else if card.isSkip {
            let count = state.players.count
            let skippedIndex = ((playerIndex + state.playDirection) % count + count) % count
            skippedPlayerID = state.players[skippedIndex].hasCards ? state.players[skippedIndex].id : nil
            publishEvent(.skip)
            message = "\(state.players[playerIndex].name) played \(card.display) — skip!"
            advanceTurn(skip: true)
            return
        } else if card.isSeven {
            publishEvent(.sevenPlayed)
            message = "\(state.players[playerIndex].name) played \(card.display)"
        } else {
            publishEvent(.normal)
            message = "\(state.players[playerIndex].name) played \(card.display)"
        }

        advanceTurn()
    }

    private func checkForBurn(card: Card, playerIndex: Int) -> Bool {
        if GameRules.isFourOfAKindBurn(pile: state.pile, triggerCard: card) {
            lastBurnWasFourOfAKind = true
            message = "Four \(card.rank.label)s — pile burned!"
            burnPile(playerIndex: playerIndex)
            return true
        }
        return false
    }

    private func burnPile(playerIndex: Int) {
        state.pile.removeAll()
        publishEvent(.burn)
        mustPlayUnderSeven = false

        if checkWin(playerIndex: playerIndex) { return }

        if !state.players[playerIndex].hasCards {
            state.currentPlayerIndex = playerIndex
            advanceTurn()
            return
        }

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
        state.players[playerIndex].hand = GameRules.sortPlayableOrder(state.players[playerIndex].hand)
        publishEvent(.pickup)
        mustPlayUnderSeven = false
        message = "\(state.players[playerIndex].name) picked up the pile"
        advanceTurn()
    }

    // MARK: - Joker

    private func handleJoker(card: Card, playerIndex: Int) {
        mustPlayUnderSeven = false
        pendingJokerPlayerIndex = playerIndex
        publishEvent(.joker)

        if state.players[playerIndex].isAI {
            message = "\(state.players[playerIndex].name) played Joker!"
        } else {
            message = "Choose a player to give the pile to!"
        }
    }

    func assignJokerPile(to targetIndex: Int) {
        guard let playerIndex = pendingJokerPlayerIndex else { return }
        pendingJokerPlayerIndex = nil
        jokerTargetPlayerID = state.players[targetIndex].id
        state.pile.removeAll { $0.isJoker }
        giveCurrentPileTo(targetIndex)
        message = "Gave the pile to \(state.players[targetIndex].name)!"
        if checkWin(playerIndex: playerIndex) { return }
        advanceTurn()
    }

    private func giveCurrentPileTo(_ targetIndex: Int) {
        state.players[targetIndex].hand.append(contentsOf: state.pile)
        state.players[targetIndex].hand = GameRules.sortPlayableOrder(state.players[targetIndex].hand)
        state.pile.removeAll()
    }

    func bestJokerTarget(playerIndex: Int) -> Int {
        var bestIdx = -1
        var fewestCards = Int.max
        for (idx, player) in state.players.enumerated() {
            guard idx != playerIndex, player.hasCards else { continue }
            let total = player.hand.count + player.faceUp.count + player.faceDown.count + player.drawPile.count
            if total < fewestCards {
                fewestCards = total
                bestIdx = idx
            }
        }
        return bestIdx >= 0 ? bestIdx : playerIndex
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
            let name = state.players[playerIndex].name
            if !state.finishOrder.contains(name) {
                state.finishOrder.append(name)
            }
            if checkGameOver() { return true }
        }
        return false
    }

    private func checkGameOver() -> Bool {
        let activePlayers = state.players.filter { $0.hasCards }
        if activePlayers.count <= 1 {
            state.phase = .finished
            if let loser = activePlayers.first {
                message = "\(loser.name) is stuck with the stack!"
            } else {
                message = "Game over — it's a tie!"
            }
            return true
        }
        return false
    }

    private func publishEvent(_ event: GameEvent) {
        lastEvent = event
        eventSerial += 1
    }

    // MARK: - AI

    func performAITurn() {
        AIPlayer.performTurn(engine: self)
    }
}
