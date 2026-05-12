//
//  _H_T_HeadTests.swift
//  Shed HeadTests
//
//  Created by Johnathan Branscum on 5/7/26.
//

import Testing
@testable import Shed_Head

struct _H_T_HeadTests {

    @Test func example() async throws {
        #expect(GameRules.canPlay(card(.three), effectiveTopCard: nil, mustPlayUnderSeven: false))
        #expect(GameRules.canPlay(card(.six), effectiveTopCard: card(.five), mustPlayUnderSeven: false))
        #expect(!GameRules.canPlay(card(.king), effectiveTopCard: card(.five), mustPlayUnderSeven: true))
        #expect(GameRules.canPlay(card(.two), effectiveTopCard: card(.ace), mustPlayUnderSeven: true))
    }

    @MainActor
    @Test func repeatedEventsStillPublish() {
        let engine = GameEngine()
        engine.state.phase = .playing
        var opponent = Player(id: "ai0", name: "Marco", avatar: "avatar_marco", isAI: true)
        opponent.hand = [card(.five)]
        engine.state.players = [
            Player(id: "human", name: "You", avatar: "", isAI: false),
            opponent
        ]
        engine.state.currentPlayerIndex = 0

        engine.state.pile = [card(.three)]
        engine.pickUpPile()
        let firstSerial = engine.eventSerial

        engine.state.currentPlayerIndex = 0
        engine.state.pile = [card(.four)]
        engine.pickUpPile()

        #expect(engine.lastEvent == .pickup)
        #expect(engine.eventSerial == firstSerial + 1)
    }

    private func card(_ rank: Rank, suit: Suit = .clubs) -> Card {
        Card(suit: suit, rank: rank)
    }
}
