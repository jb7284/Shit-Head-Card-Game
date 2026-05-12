import Foundation

enum GameDealer {
    static func newGameState(playerCount: Int) -> GameState {
        let clamped = min(max(playerCount, 2), 6)
        let state = GameState()
        state.deck = Deck.standard(deckCount: deckCount(for: clamped))
        state.players = makePlayers(count: clamped)
        deal(into: state)
        return state
    }

    static func refillHand(_ player: inout Player) {
        while player.hand.count < 3, !player.drawPile.isEmpty {
            player.hand.append(player.drawPile.removeFirst())
        }
        player.hand = GameRules.sortPlayableOrder(player.hand)
    }

    private static func deckCount(for playerCount: Int) -> Int {
        if playerCount <= 2 { return 1 }
        if playerCount <= 4 { return 2 }
        return 3
    }

    private static func makePlayers(count: Int) -> [Player] {
        let aiCharacters: [(name: String, avatar: String)] = [
            ("Marco", "avatar_marco"),
            ("Sofia", "avatar_sofia"),
            ("Dante", "avatar_dante"),
            ("Ava", "avatar_ava"),
            ("Jake", "avatar_jake"),
        ]

        let shuffled = aiCharacters.shuffled()
        var players = [Player(id: "human", name: "You", avatar: "", isAI: false)]
        for index in 0..<(count - 1) {
            let character = shuffled[index]
            players.append(Player(id: "ai\(index)", name: character.name, avatar: character.avatar, isAI: true))
        }
        return players
    }

    private static func deal(into state: GameState) {
        for index in state.players.indices {
            state.players[index].faceDown = state.deck.draw(3)
            state.players[index].faceUp = state.deck.draw(3)
        }

        var playerIndex = 0
        while let card = state.deck.draw() {
            state.players[playerIndex].drawPile.append(card)
            playerIndex = (playerIndex + 1) % state.players.count
        }

        for index in state.players.indices {
            refillHand(&state.players[index])
        }

        state.phase = .swapping
        state.currentPlayerIndex = 0
    }
}
