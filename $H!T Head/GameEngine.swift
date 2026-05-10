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

    // MARK: - Setup

    func startNewGame(playerCount: Int = 2, difficulty: Difficulty = .medium) {
        self.difficulty = difficulty
        eventSerial = 0
        lastEvent = .none
        mustPlayUnderSeven = false
        openingCard = nil
        state = GameDealer.newGameState(playerCount: playerCount)
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

    private func determineStartingPlayer() -> Int {
        let suitOrder: [Suit] = [.clubs, .diamonds, .spades, .hearts]
        for rank in Rank.allCases where rank != .two {
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
        switch difficulty {
        case .easy:
            break
        case .medium:
            performMediumSwaps()
        case .expert:
            performExpertSwaps()
        }
    }

    private func performMediumSwaps() {
        for i in state.players.indices where state.players[i].isAI {
            var hand = state.players[i].hand
            var faceUp = state.players[i].faceUp

            for h in 0..<hand.count {
                for f in 0..<faceUp.count {
                    if GameRules.faceUpDesirability(hand[h]) > GameRules.faceUpDesirability(faceUp[f]) {
                        let temp = hand[h]
                        hand[h] = faceUp[f]
                        faceUp[f] = temp
                    }
                }
            }

            state.players[i].hand = hand
            state.players[i].faceUp = faceUp
        }
    }

    private func performExpertSwaps() {
        for i in state.players.indices where state.players[i].isAI {
            let allCards = state.players[i].hand + state.players[i].faceUp
            var chosenFaceUp: [Card] = []

            // Best setup: burn card (10) + matching pair
            // Play the pair on empty pile after burning — sheds 3 cards in a row
            if let ten = allCards.first(where: { $0.isBurn }) {
                let candidates = allCards.filter { $0 != ten && !$0.isWild && !$0.isBurn }
                let grouped = Dictionary(grouping: candidates) { $0.rank }
                if let pair = grouped.values.first(where: { $0.count >= 2 }) {
                    chosenFaceUp = [ten, pair[0], pair[1]]
                }
            }

            if chosenFaceUp.isEmpty {
                chosenFaceUp = Array(
                    allCards.sorted {
                        GameRules.faceUpDesirability($0) > GameRules.faceUpDesirability($1)
                    }.prefix(3)
                )
            }

            var remaining = allCards
            for chosen in chosenFaceUp {
                if let idx = remaining.firstIndex(of: chosen) {
                    remaining.remove(at: idx)
                }
            }

            state.players[i].faceUp = chosenFaceUp
            state.players[i].hand = remaining.sorted { $0.rank < $1.rank }
        }
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

    // MARK: - After Play Logic

    private func afterPlay(card: Card, playerIndex: Int) {
        openingCard = nil

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
                message = "\(loser.name) is the Sh*t Head!"
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
        if let required = openingCard {
            playCards([required])
            return
        }
        switch difficulty {
        case .easy: performEasyTurn()
        case .medium: performMediumTurn()
        case .expert: performExpertTurn()
        }
    }

    // MARK: Easy — plays lowest single card, no grouping, wastes specials

    private func performEasyTurn() {
        let player = state.currentPlayer

        if player.playingFrom == .faceDown {
            playFaceDownAt(index: Int.random(in: 0..<player.faceDown.count))
            return
        }

        let playable = playableCards(for: player)
        guard !playable.isEmpty else {
            pickUpPile()
            return
        }

        let lowest = playable.min(by: { $0.rank < $1.rank })!
        playCards([lowest])
    }

    // MARK: Medium — groups by rank, completes four-of-a-kind, basic special management

    private func performMediumTurn() {
        let player = state.currentPlayer

        if player.playingFrom == .faceDown {
            playFaceDownAt(index: Int.random(in: 0..<player.faceDown.count))
            return
        }

        let playable = playableCards(for: player)
        guard !playable.isEmpty else {
            pickUpPile()
            return
        }

        let grouped = Dictionary(grouping: playable) { $0.rank }

        if let topCard = state.topCard {
            let topCount = state.pile.suffix(3).filter { $0.rank == topCard.rank }.count
            if let matching = grouped[topCard.rank], matching.count + topCount >= 4 {
                let needed = 4 - topCount
                playCards(Array(matching.prefix(needed)))
                return
            }
        }

        let regular = playable.filter { !$0.isWild && !$0.isBurn }
        let wilds = grouped[.two] ?? []
        let burns = grouped[.ten] ?? []

        if !regular.isEmpty {
            let lowestRank = regular.min(by: { $0.rank < $1.rank })!.rank
            let toPlay = regular.filter { $0.rank == lowestRank }
            playCards(toPlay)
            return
        }

        if !burns.isEmpty && (state.pile.count >= 3 || wilds.isEmpty) {
            playCards([burns[0]])
            return
        }

        if !wilds.isEmpty {
            playCards([wilds[0]])
            return
        }

        if !burns.isEmpty {
            playCards([burns[0]])
            return
        }

        pickUpPile()
    }

    // MARK: Expert — strategic special management, targeted 7s, pile pressure, mid-range play

    private func performExpertTurn() {
        let player = state.currentPlayer

        if player.playingFrom == .faceDown {
            playFaceDownAt(index: Int.random(in: 0..<player.faceDown.count))
            return
        }

        let playable = playableCards(for: player)
        guard !playable.isEmpty else {
            pickUpPile()
            return
        }

        let grouped = Dictionary(grouping: playable) { $0.rank }
        let regular = playable.filter { !$0.isWild && !$0.isBurn }
        let wilds = grouped[.two] ?? []
        let burns = grouped[.ten] ?? []
        let sevens = grouped[.seven] ?? []
        let normalRegular = regular.filter { !$0.isSeven }

        // 1. Always complete a four-of-a-kind burn — free pile clear + go again
        if let topCard = state.topCard {
            let topCount = state.pile.suffix(3).filter { $0.rank == topCard.rank }.count
            if let matching = grouped[topCard.rank], matching.count + topCount >= 4 {
                let needed = 4 - topCount
                playCards(Array(matching.prefix(needed)))
                return
            }
        }

        // 2. Targeted 7: play when next opponent is on face-up with high cards
        if !sevens.isEmpty && canPlay(sevens[0]) {
            if let next = nextActivePlayer(),
               next.hand.isEmpty && next.drawPile.isEmpty && !next.faceUp.isEmpty {
                let highCount = next.faceUp.filter { $0.rank.rawValue >= Rank.jack.rawValue }.count
                if highCount >= 2 {
                    playCards([sevens[0]])
                    return
                }
            }
        }

        // 3. Lead with a rank held 3+ of — set up a potential self-burn next turn
        if !normalRegular.isEmpty {
            let normalGrouped = Dictionary(grouping: normalRegular) { $0.rank }
            for (_, cards) in normalGrouped.sorted(by: { $0.key < $1.key }) {
                if cards.count >= 3 && canPlay(cards[0]) {
                    playCards(cards)
                    return
                }
            }
        }

        // 4. Play from the middle of the range — protect low cards (insurance for low piles)
        //    and high cards (insurance for high piles)
        if !normalRegular.isEmpty {
            let sorted = normalRegular.sorted { $0.rank < $1.rank }
            let midRank = sorted[sorted.count / 2].rank
            let toPlay = normalRegular.filter { $0.rank == midRank }
            playCards(toPlay)
            return
        }

        // 5. Play 7 normally if it's the only regular card left
        if !sevens.isEmpty && canPlay(sevens[0]) {
            playCards([sevens[0]])
            return
        }

        // 6. Pile pressure: only burn large piles (5+) — hold the 10 as insurance
        //    and let the pile grow to threaten opponents who don't have a burn
        if !burns.isEmpty && state.pile.count >= 5 {
            playCards([burns[0]])
            return
        }

        // 7. Wild as last resort before burning a small pile
        if !wilds.isEmpty {
            playCards([wilds[0]])
            return
        }

        // 8. Forced burn on a small pile — no other option
        if !burns.isEmpty {
            playCards([burns[0]])
            return
        }

        pickUpPile()
    }

    private func nextActivePlayer() -> Player? {
        let count = state.players.count
        var idx = state.currentPlayerIndex
        for _ in 0..<count {
            idx = ((idx + state.playDirection) % count + count) % count
            if state.players[idx].hasCards && idx != state.currentPlayerIndex {
                return state.players[idx]
            }
        }
        return nil
    }
}
