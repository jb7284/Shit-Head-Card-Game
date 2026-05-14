import Foundation

enum AIPlayer {

    // MARK: - Swap Phase

    static func performSwaps(state: GameState, difficulty: Difficulty) {
        switch difficulty {
        case .easy:
            break
        case .medium:
            performMediumSwaps(state: state)
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

    // MARK: - Turn Execution

    static func performTurn(engine: GameEngine) {
        if let required = engine.openingCard {
            engine.playCards([required])
            return
        }
        switch engine.difficulty {
        case .easy: performEasyTurn(engine: engine)
        case .medium: performMediumTurn(engine: engine)
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

}
