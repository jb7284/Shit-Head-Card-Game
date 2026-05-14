//
//  _H_T_HeadTests.swift
//  Shed HeadTests
//
//  Created by Johnathan Branscum on 5/7/26.
//

import Testing
@testable import Shed_Head

struct _H_T_HeadTests {

    @MainActor
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

    @Test func aiPacingKeepsBurnsAndJokersFastAfterHumanIsOut() {
        #expect(AIPacing.turnDelay(humanOut: true, burnPending: false) == .milliseconds(75))
        #expect(AIPacing.turnDelay(humanOut: true, burnPending: true) == .milliseconds(75))
        #expect(AIPacing.jokerDelay(humanOut: true) == .milliseconds(75))
        #expect(AIPacing.burnEffectDelay(playFlightDuration: 0.45, humanOut: true) == 0.05)
    }

    @MainActor
    @Test func tutorialDealGivesHumanControlledLessonCardsAndLowestStarter() {
        let state = GameDealer.newTutorialGameState(playerCount: 4)
        let human = state.players[0]
        let visibleBeforeSwap = human.hand + human.faceUp

        #expect(state.phase == .swapping)
        #expect(human.hand.contains(where: { $0.rank == .three && $0.suit == .clubs }))
        #expect(lowestNonWildRank(in: human.hand) == .three)
        #expect(visibleBeforeSwap.contains(where: { $0.rank == .two }))
        #expect(visibleBeforeSwap.contains(where: { $0.rank == .ten }))
        #expect(visibleBeforeSwap.contains(where: { $0.rank == .joker }))
    }

    @MainActor
    @Test func tutorialControllerStartsWithGoalThenSwapThenDemo() {
        let tutorial = TutorialModeController()

        tutorial.start()
        #expect(tutorial.currentOverlay?.lesson == .goal)

        tutorial.dismissCurrentOverlay()
        #expect(tutorial.currentOverlay?.lesson == .swapBeforePlay)

        tutorial.dismissCurrentOverlay()
        #expect(tutorial.currentOverlay == nil)
        #expect(tutorial.activeDemo?.kind == .swap)
        #expect(tutorial.blocksInput)
    }

    @MainActor
    @Test func tutorialSwapDemoTargetsActualSwapCards() {
        let engine = GameEngine()
        let tutorial = TutorialModeController()

        engine.startTutorialGame()
        tutorial.start()
        tutorial.dismissCurrentOverlay(engine: engine)
        tutorial.dismissCurrentOverlay(engine: engine)

        let demoCards = tutorial.activeDemo?.cards ?? []
        #expect(tutorial.activeDemo?.kind == .swap)
        #expect(demoCards.contains { $0.rank == .two })
        #expect(demoCards.contains { $0.rank == .ten })
        #expect(demoCards.allSatisfy { engine.state.players[0].hand.contains($0) || engine.state.players[0].faceUp.contains($0) })
    }

    @MainActor
    @Test func tutorialSeedsCenterPileAndTeachesPlayBeforeFirstCard() {
        let engine = GameEngine()
        let tutorial = TutorialModeController()

        engine.startTutorialGame()
        engine.confirmSwap()
        engine.forceHumanTutorialTurn()

        #expect(engine.state.pile.isEmpty)

        tutorial.start()
        tutorial.dismissCurrentOverlay()
        tutorial.dismissCurrentOverlay()
        tutorial.finishActiveDemo()

        tutorial.showNextLessonIfNeeded(engine: engine)
        #expect(tutorial.currentOverlay?.lesson == .lowestStarts)

        tutorial.dismissCurrentOverlay(engine: engine)
        #expect(tutorial.currentOverlay?.lesson == .centerPile)

        tutorial.dismissCurrentOverlay(engine: engine)
        #expect(tutorial.currentOverlay?.lesson == .playCards)

        tutorial.dismissCurrentOverlay(engine: engine)
        #expect(tutorial.activeDemo?.kind == .playCard)
        #expect(!tutorial.blocksInput)
        #expect(tutorial.activeDemo?.cards.first?.rank == .three)
        #expect(tutorial.activeDemo?.topCard == nil)
    }

    @MainActor
    @Test func tutorialHighlightsActualPlayableLessonCards() {
        let engine = GameEngine()
        let tutorial = TutorialModeController()

        engine.startTutorialGame()
        engine.confirmSwap()
        engine.forceHumanTutorialTurn()
        tutorial.start()
        tutorial.dismissCurrentOverlay()
        tutorial.dismissCurrentOverlay()
        tutorial.finishActiveDemo()

        tutorial.showNextLessonIfNeeded(engine: engine)
        tutorial.dismissCurrentOverlay(engine: engine)
        tutorial.dismissCurrentOverlay(engine: engine)
        tutorial.dismissCurrentOverlay(engine: engine)

        let highlighted = tutorial.highlightedCardIDs
        let human = engine.state.players[0]
        let three = human.hand.first { $0.rank == .three }
        #expect(three.map { highlighted.contains($0.uid) } == true)
    }

    @MainActor
    @Test func tutorialDoesNotTeachTenOrJokerWhenPileIsEmpty() {
        let engine = GameEngine()
        var human = Player(id: "human", name: "You", avatar: "", isAI: false)
        human.hand = [card(.ten), card(.joker)]
        var ai = Player(id: "ai0", name: "Marco", avatar: "avatar_marco", isAI: true)
        ai.hand = [card(.five)]
        engine.state.phase = .playing
        engine.state.players = [human, ai]
        engine.state.currentPlayerIndex = 0
        engine.state.pile = []
        let tutorial = tutorialReadyForGameplayLesson(engine: engine)
        tutorial.markPlayerActed()
        tutorial.markPlayerActed()
        tutorial.markPlayerActed()

        tutorial.showNextLessonIfNeeded(engine: engine)

        #expect(tutorial.currentOverlay?.lesson != .specialTen)
        #expect(tutorial.currentOverlay?.lesson != .joker)
    }

    @MainActor
    @Test func tutorialDoesNotTeachTenWhenAnotherCardCanPlay() {
        let engine = GameEngine()
        var human = Player(id: "human", name: "You", avatar: "", isAI: false)
        human.hand = [card(.six), card(.ten)]
        var ai = Player(id: "ai0", name: "Marco", avatar: "avatar_marco", isAI: true)
        ai.hand = [card(.king)]
        engine.state.phase = .playing
        engine.state.players = [human, ai]
        engine.state.currentPlayerIndex = 0
        engine.state.pile = [card(.five)]
        let tutorial = tutorialReadyForGameplayLesson(engine: engine)
        tutorial.markPlayerActed()
        tutorial.markPlayerActed()
        tutorial.markPlayerActed()

        tutorial.showNextLessonIfNeeded(engine: engine)

        #expect(tutorial.currentOverlay?.lesson != .specialTen)
    }

    @MainActor
    @Test func tutorialTeachesTenWhenTenIsOnlyPlayableCard() {
        let engine = GameEngine()
        var human = Player(id: "human", name: "You", avatar: "", isAI: false)
        human.hand = [card(.six), card(.ten)]
        var ai = Player(id: "ai0", name: "Marco", avatar: "avatar_marco", isAI: true)
        ai.hand = [card(.king)]
        engine.state.phase = .playing
        engine.state.players = [human, ai]
        engine.state.currentPlayerIndex = 0
        engine.state.pile = [card(.queen)]
        let tutorial = tutorialReadyForGameplayLesson(engine: engine)
        tutorial.markPlayerActed()
        tutorial.markPlayerActed()
        tutorial.markPlayerActed()

        tutorial.showNextLessonIfNeeded(engine: engine)

        #expect(tutorial.currentOverlay?.lesson == .specialTen)
        #expect(tutorial.currentOverlay?.tipTitle == "Tip")
    }

    @Test func tutorialJokerCopyIncludesSaveAndTargetTips() {
        let joker = TutorialOverlayContent(lesson: .joker)
        let choosingTarget = TutorialOverlayContent(lesson: .jokerStrategy)

        #expect(joker.tipTitle == "Tip")
        #expect(joker.tipMessage?.contains("large") == true)
        #expect(joker.tipMessage?.contains("opponent") == true)
        #expect(choosingTarget.message.contains("player you don't like") == true)
        #expect(choosingTarget.message.contains("😉") == true)
    }

    @MainActor
    @Test func tutorialProvidesHighlightedMatchingGroupForPlay() {
        let engine = GameEngine()
        let queenOne = card(.queen, suit: .hearts)
        let queenTwo = card(.queen, suit: .diamonds)
        var human = Player(id: "human", name: "You", avatar: "", isAI: false)
        human.hand = [queenOne, queenTwo]
        var ai = Player(id: "ai0", name: "Marco", avatar: "avatar_marco", isAI: true)
        ai.hand = [card(.king)]
        engine.state.phase = .playing
        engine.state.players = [human, ai]
        engine.state.currentPlayerIndex = 0
        engine.state.pile = [card(.jack)]
        let tutorial = tutorialReadyForGameplayLesson(engine: engine)
        tutorial.markPlayerActed()
        tutorial.markPlayerActed()
        tutorial.markPlayerActed()

        tutorial.showNextLessonIfNeeded(engine: engine)
        if tutorial.currentOverlay?.lesson == .lowestPlayableTip {
            tutorial.dismissCurrentOverlay(engine: engine)
            tutorial.markPlayerActed()
            tutorial.markPlayerActed()
            tutorial.showNextLessonIfNeeded(engine: engine)
        }
        tutorial.dismissCurrentOverlay(engine: engine)
        tutorial.finishActiveDemo()

        let group = tutorial.highlightedPlayableGroup(tapped: queenOne, engine: engine)
        #expect(group?.map(\.rank) == [.queen, .queen])
    }

    @MainActor
    @Test func tutorialDoesNotAdvanceLessonsWhileJokerTargetIsPending() {
        let engine = GameEngine()
        let tutorial = TutorialModeController()
        var human = Player(id: "human", name: "You", avatar: "", isAI: false)
        human.hand = [
            card(.joker),
            card(.queen, suit: .hearts),
            card(.queen, suit: .diamonds)
        ]
        var ai = Player(id: "ai0", name: "Marco", avatar: "avatar_marco", isAI: true)
        ai.hand = [card(.five)]
        engine.state.phase = .playing
        engine.state.players = [human, ai]
        engine.state.currentPlayerIndex = 0
        engine.state.pile = [card(.six)]
        engine.pendingJokerPlayerIndex = 0

        tutorial.start()
        tutorial.dismissCurrentOverlay()
        tutorial.dismissCurrentOverlay()
        tutorial.finishActiveDemo()
        tutorial.markPlayerActed()
        tutorial.showNextLessonIfNeeded(engine: engine)

        #expect(tutorial.currentOverlay == nil)
    }

    private func card(_ rank: Rank, suit: Suit = .clubs) -> Card {
        Card(suit: suit, rank: rank)
    }

    @MainActor
    private func tutorialReadyForGameplayLesson(engine: GameEngine) -> TutorialModeController {
        let tutorial = TutorialModeController()
        tutorial.start()
        tutorial.dismissCurrentOverlay()
        tutorial.dismissCurrentOverlay()
        tutorial.finishActiveDemo()
        tutorial.showNextLessonIfNeeded(engine: engine)
        tutorial.dismissCurrentOverlay(engine: engine)
        tutorial.dismissCurrentOverlay(engine: engine)
        tutorial.dismissCurrentOverlay(engine: engine)
        tutorial.markPlayerActed()
        return tutorial
    }

    private func lowestNonWildRank(in cards: [Card]) -> Rank? {
        cards
            .filter { $0.rank != .two && $0.rank != .joker }
            .map(\.rank)
            .min()
    }
}
