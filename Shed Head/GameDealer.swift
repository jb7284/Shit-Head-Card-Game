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

    static func newTutorialGameState(playerCount: Int) -> GameState {
        let clamped = min(max(playerCount, 2), 4)
        let state = GameState()
        state.deck = Deck(cards: [])
        state.players = makePlayers(count: clamped)
        dealTutorialCards(into: state)
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

    private static func dealTutorialCards(into state: GameState) {
        guard !state.players.isEmpty else { return }

        state.players[0].hand = GameRules.sortPlayableOrder([
            Card(suit: .clubs, rank: .three),
            Card(suit: .hearts, rank: .two),
            Card(suit: .diamonds, rank: .five)
        ])
        state.players[0].faceUp = [
            Card(suit: .hearts, rank: .ten),
            Card(suit: .diamonds, rank: .joker),
            Card(suit: .spades, rank: .eight)
        ]
        state.players[0].faceDown = [
            Card(suit: .clubs, rank: .nine),
            Card(suit: .diamonds, rank: .joker),
            Card(suit: .spades, rank: .ace)
        ]
        state.players[0].drawPile = [
            Card(suit: .clubs, rank: .ten),
            Card(suit: .clubs, rank: .seven),
            Card(suit: .hearts, rank: .eight),
            Card(suit: .hearts, rank: .nine),
            Card(suit: .spades, rank: .joker),
            Card(suit: .hearts, rank: .queen),
            Card(suit: .diamonds, rank: .queen),
            Card(suit: .spades, rank: .queen),
            Card(suit: .clubs, rank: .queen),
            Card(suit: .diamonds, rank: .six),
            Card(suit: .spades, rank: .ace)
        ]

        let aiHands: [[Card]] = [
            [
                Card(suit: .diamonds, rank: .four),
                Card(suit: .clubs, rank: .five),
                Card(suit: .hearts, rank: .eight)
            ],
            [
                Card(suit: .spades, rank: .five),
                Card(suit: .clubs, rank: .six),
                Card(suit: .diamonds, rank: .nine)
            ],
            [
                Card(suit: .hearts, rank: .six),
                Card(suit: .spades, rank: .seven),
                Card(suit: .clubs, rank: .king)
            ]
        ]

        for index in state.players.indices.dropFirst() {
            let hand = aiHands[(index - 1) % aiHands.count]
            state.players[index].hand = GameRules.sortPlayableOrder(hand)
            state.players[index].faceUp = [
                Card(suit: .hearts, rank: .jack),
                Card(suit: .diamonds, rank: .king),
                Card(suit: .clubs, rank: .ace)
            ]
            state.players[index].faceDown = [
                Card(suit: .clubs, rank: .four),
                Card(suit: .diamonds, rank: .six),
                Card(suit: .spades, rank: .queen)
            ]
            state.players[index].drawPile = [
                Card(suit: .hearts, rank: .five),
                Card(suit: .diamonds, rank: .eight),
                Card(suit: .spades, rank: .ten)
            ]
        }

        state.phase = .swapping
        state.currentPlayerIndex = 0
        state.playDirection = 1
        state.turnNumber = 0
    }
}
