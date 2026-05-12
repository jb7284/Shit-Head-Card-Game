import Foundation

enum AIPlayer {

    // MARK: - Swap Phase

    static func performSwaps(state: GameState, difficulty: Difficulty) {
        switch difficulty {
        case .easy:
            break
        case .medium:
            performMediumSwaps(state: state)
        case .expert:
            performExpertSwaps(state: state)
        }
    }

    private static func performMediumSwaps(state: GameState) {
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

    private static func performExpertSwaps(state: GameState) {
        for i in state.players.indices where state.players[i].isAI {
            let allCards = state.players[i].hand + state.players[i].faceUp
            var chosenFaceUp: [Card] = []

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

    // MARK: - Turn Execution

    static func performTurn(engine: GameEngine) {
        if let required = engine.openingCard {
            engine.playCards([required])
            return
        }
        switch engine.difficulty {
        case .easy: performEasyTurn(engine: engine)
        case .medium: performMediumTurn(engine: engine)
        case .expert: performExpertTurn(engine: engine)
        }
    }

    // MARK: Easy

    private static func performEasyTurn(engine: GameEngine) {
        let player = engine.state.currentPlayer

        if player.playingFrom == .faceDown {
            engine.playFaceDownAt(index: Int.random(in: 0..<player.faceDown.count))
            return
        }

        let playable = engine.playableCards(for: player)
        guard !playable.isEmpty else {
            engine.pickUpPile()
            return
        }

        if let lowest = playable.min(by: { $0.rank < $1.rank }) {
            engine.playCards([lowest])
        }
    }

    // MARK: Medium

    private static func performMediumTurn(engine: GameEngine) {
        let player = engine.state.currentPlayer

        if player.playingFrom == .faceDown {
            engine.playFaceDownAt(index: Int.random(in: 0..<player.faceDown.count))
            return
        }

        let playable = engine.playableCards(for: player)
        guard !playable.isEmpty else {
            engine.pickUpPile()
            return
        }

        let grouped = Dictionary(grouping: playable) { $0.rank }

        if let topCard = engine.state.topCard {
            let topCount = engine.state.pile.suffix(3).filter { $0.rank == topCard.rank }.count
            if let matching = grouped[topCard.rank], matching.count + topCount >= 4 {
                let needed = 4 - topCount
                engine.playCards(Array(matching.prefix(needed)))
                return
            }
        }

        let regular = playable.filter { !$0.isWild && !$0.isBurn && !$0.isJoker }
        let wilds = grouped[.two] ?? []
        let burns = grouped[.ten] ?? []
        let jokers = grouped[.joker] ?? []

        if !jokers.isEmpty && engine.state.pile.count >= 4 {
            engine.playCards([jokers[0]])
            return
        }

        if !regular.isEmpty {
            if let lowestRank = regular.min(by: { $0.rank < $1.rank })?.rank {
                let toPlay = regular.filter { $0.rank == lowestRank }
                engine.playCards(toPlay)
            }
            return
        }

        if !burns.isEmpty && (engine.state.pile.count >= 3 || wilds.isEmpty) {
            engine.playCards([burns[0]])
            return
        }

        if !wilds.isEmpty {
            engine.playCards([wilds[0]])
            return
        }

        if !burns.isEmpty {
            engine.playCards([burns[0]])
            return
        }

        if !jokers.isEmpty {
            engine.playCards([jokers[0]])
            return
        }

        engine.pickUpPile()
    }

    // MARK: Expert

    private static func performExpertTurn(engine: GameEngine) {
        let player = engine.state.currentPlayer

        if player.playingFrom == .faceDown {
            engine.playFaceDownAt(index: Int.random(in: 0..<player.faceDown.count))
            return
        }

        let playable = engine.playableCards(for: player)
        guard !playable.isEmpty else {
            engine.pickUpPile()
            return
        }

        let grouped = Dictionary(grouping: playable) { $0.rank }
        let regular = playable.filter { !$0.isWild && !$0.isBurn && !$0.isJoker }
        let wilds = grouped[.two] ?? []
        let burns = grouped[.ten] ?? []
        let sevens = grouped[.seven] ?? []
        let jokers = grouped[.joker] ?? []
        let normalRegular = regular.filter { !$0.isSeven }

        // 1. Always complete a four-of-a-kind burn
        if let topCard = engine.state.topCard {
            let topCount = engine.state.pile.suffix(3).filter { $0.rank == topCard.rank }.count
            if let matching = grouped[topCard.rank], matching.count + topCount >= 4 {
                let needed = 4 - topCount
                engine.playCards(Array(matching.prefix(needed)))
                return
            }
        }

        // 2. Targeted 7: play when next opponent is on face-up with high cards
        if !sevens.isEmpty && engine.canPlay(sevens[0]) {
            if let next = nextActivePlayer(engine: engine),
               next.hand.isEmpty && next.drawPile.isEmpty && !next.faceUp.isEmpty {
                let highCount = next.faceUp.filter { $0.rank.rawValue >= Rank.jack.rawValue }.count
                if highCount >= 2 {
                    engine.playCards([sevens[0]])
                    return
                }
            }
        }

        // 3. Joker: dump a big pile on the player closest to going out
        if !jokers.isEmpty && engine.state.pile.count >= 5 {
            engine.playCards([jokers[0]])
            return
        }

        // 4. Lead with a rank held 3+ of
        if !normalRegular.isEmpty {
            let normalGrouped = Dictionary(grouping: normalRegular) { $0.rank }
            for (_, cards) in normalGrouped.sorted(by: { $0.key < $1.key }) {
                if cards.count >= 3 && engine.canPlay(cards[0]) {
                    engine.playCards(cards)
                    return
                }
            }
        }

        // 5. Play from the middle of the range
        if !normalRegular.isEmpty {
            let sorted = normalRegular.sorted { $0.rank < $1.rank }
            let midRank = sorted[sorted.count / 2].rank
            let toPlay = normalRegular.filter { $0.rank == midRank }
            engine.playCards(toPlay)
            return
        }

        // 6. Play 7 normally if it's the only regular card left
        if !sevens.isEmpty && engine.canPlay(sevens[0]) {
            engine.playCards([sevens[0]])
            return
        }

        // 7. Pile pressure: only burn large piles (5+)
        if !burns.isEmpty && engine.state.pile.count >= 5 {
            engine.playCards([burns[0]])
            return
        }

        // 8. Wild as last resort before burning a small pile
        if !wilds.isEmpty {
            engine.playCards([wilds[0]])
            return
        }

        // 9. Forced burn on a small pile
        if !burns.isEmpty {
            engine.playCards([burns[0]])
            return
        }

        // 10. Joker as last resort
        if !jokers.isEmpty {
            engine.playCards([jokers[0]])
            return
        }

        engine.pickUpPile()
    }

    // MARK: - Helpers

    private static func nextActivePlayer(engine: GameEngine) -> Player? {
        let count = engine.state.players.count
        var idx = engine.state.currentPlayerIndex
        for _ in 0..<count {
            idx = ((idx + engine.state.playDirection) % count + count) % count
            if engine.state.players[idx].hasCards && idx != engine.state.currentPlayerIndex {
                return engine.state.players[idx]
            }
        }
        return nil
    }
}
