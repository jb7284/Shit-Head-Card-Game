import SwiftUI

enum TutorialLesson: CaseIterable {
    case goal
    case swapBeforePlay
    case lowestStarts
    case centerPile
    case playCards
    case lowestPlayableTip
    case matchingCards
    case pickupPile
    case specialTwo
    case specialSeven
    case specialEight
    case specialNine
    case specialTen
    case joker
    case jokerStrategy
    case queenTrapExpert
    case fourOfKind
    case faceUpCards
    case jokerBeforeTenExpert
    case faceDownCards

    var title: String {
        switch self {
        case .goal: return "The Goal"
        case .swapBeforePlay: return "Swap Before You Play"
        case .lowestStarts: return "Lowest Card Starts"
        case .centerPile: return "The Center Pile"
        case .playCards: return "How To Play Cards"
        case .lowestPlayableTip: return "Tip"
        case .matchingCards: return "Play Matching Cards Together"
        case .pickupPile: return "Picking Up The Center Pile"
        case .specialTwo: return "2 Resets The Pile"
        case .specialSeven: return "7 Changes The Next Play"
        case .specialEight: return "8 Skips A Player"
        case .specialNine: return "9 Reverses Direction"
        case .specialTen: return "10 Burns The Pile"
        case .joker: return "Joker Gives The Pile Away"
        case .jokerStrategy: return "Choosing Who Gets The Pile"
        case .queenTrapExpert: return "Expert Tip"
        case .fourOfKind: return "Four Of A Kind Burns"
        case .faceUpCards: return "Face-Up Table Cards"
        case .jokerBeforeTenExpert: return "Expert Tip"
        case .faceDownCards: return "Face-Down Table Cards"
        }
    }

    var message: String {
        switch self {
        case .goal:
            return "Get rid of all your cards first... But definitely DON\u{2019}T BE LAST."
        case .swapBeforePlay:
            return "Before the first turn, swap cards from your hand with face-up table cards to set up stronger cards for later."
        case .lowestStarts:
            return "The player with the lowest card that is not a wild card starts."
        case .centerPile:
            return "Cards played go into the center pile."
        case .playCards:
            return "Double tap a playable card, or drag it toward the center pile and let go."
        case .lowestPlayableTip:
            return "Most turns, the best move is the lowest card that can legally play. Save stronger cards for tougher piles, but watch for chances to skip, reverse, burn, or trap another player."
        case .matchingCards:
            return "If you have matching ranks, select the matching cards and play them together."
        case .pickupPile:
            return "When you cannot play, pick up the center pile. Those cards move into your hand."
        case .specialTwo:
            return "A 2 is wild. It can be played on anything and resets what the next player has to beat."
        case .specialSeven:
            return "After a 7, the next card must be 7 or lower, unless it is a special card."
        case .specialEight:
            return "An 8 skips the next active player."
        case .specialNine:
            return "A 9 reverses the direction of play."
        case .specialTen:
            return "A 10 burns the pile. Burning clears every card in the center pile, and you get another turn."
        case .joker:
            return "A Joker lets you choose another player to take the center pile."
        case .jokerStrategy:
            return "Give the pile to the player with the fewest total cards, or use it to slow down a player who is close to going out. Or to the player you don't like. 😉"
        case .queenTrapExpert:
            return "The next player is down to a face-up Jack. You can play your lower cards on the 5, but a Queen raises the pile above their Jack and forces them to pick it up."
        case .fourOfKind:
            return "Four cards of the same rank on top of the pile burn automatically."
        case .faceUpCards:
            return "When your hand and draw pile are empty, you play your face-up table cards."
        case .jokerBeforeTenExpert:
            return "Play the Joker before the 10. The Joker lets you give this pile to an opponent; if you play the 10 first, the pile burns and there is nothing left to give away."
        case .faceDownCards:
            return "Face-down cards are last. Flip one and hope it can play. If it can\u{2019}t play you have to pick up all cards in the pile."
        }
    }

    var tipTitle: String? {
        switch self {
        case .specialTen, .joker:
            return "Tip"
        default:
            return nil
        }
    }

    var tipMessage: String? {
        switch self {
        case .specialTen:
            return "10s are strongest when they bail you out. Try saving them for turns when nothing else can beat the pile, so you can clear it instead of picking it up."
        case .joker:
            return "Jokers are most effective when the center pile is large. Saving one for a bigger pile can make it much more painful for an opponent."
        default:
            return nil
        }
    }

    var demoKind: TutorialDemoKind? {
        switch self {
        case .goal, .lowestStarts, .centerPile, .lowestPlayableTip, .jokerStrategy, .queenTrapExpert, .jokerBeforeTenExpert:
            return nil
        case .swapBeforePlay:
            return .swap
        case .playCards, .specialTwo, .specialSeven, .specialEight, .specialTen, .joker, .fourOfKind, .faceUpCards:
            return .playCard
        case .specialNine:
            return .reverse
        case .matchingCards:
            return .multiCard
        case .pickupPile:
            return .pickup
        case .faceDownCards:
            return .faceDown
        }
    }
}

enum TutorialDemoKind: Equatable {
    case swap
    case playCard
    case multiCard
    case pickup
    case faceDown
    case reverse
}

struct TutorialDemo: Equatable {
    let kind: TutorialDemoKind
    let cards: [Card]
    let topCard: Card?
    let repeatsUntilPlayerAction: Bool
}

struct TutorialOverlayContent: Equatable {
    let lesson: TutorialLesson
    let title: String
    let message: String
    let tipTitle: String?
    let tipMessage: String?
    let buttonTitle: String

    init(lesson: TutorialLesson) {
        self.lesson = lesson
        self.title = lesson.title
        self.message = lesson.message
        self.tipTitle = lesson.tipTitle
        self.tipMessage = lesson.tipMessage
        self.buttonTitle = lesson == .goal ? "Start" : "Next"
    }
}

@MainActor
@Observable
final class TutorialModeController {
    var isActive = false
    var currentOverlay: TutorialOverlayContent?
    var activeDemo: TutorialDemo?
    var highlightedCardIDs = Set<UUID>()

    private var completedLessons = Set<TutorialLesson>()
    private var demoLesson: TutorialLesson?
    private var awaitingPlayerAction = false
    private var playerActionsSinceLesson = 0
    private var totalPlayerActions = 0
    private var nextSpacingIndex = 0
    private let lessonSpacings = [1, 2, 3]

    var blocksInput: Bool {
        currentOverlay != nil || (activeDemo != nil && activeDemo?.repeatsUntilPlayerAction != true)
    }

    var blocksAI: Bool {
        currentOverlay != nil || activeDemo != nil
    }

    func start() {
        isActive = true
        completedLessons.removeAll()
        awaitingPlayerAction = false
        demoLesson = nil
        activeDemo = nil
        highlightedCardIDs.removeAll()
        playerActionsSinceLesson = 0
        totalPlayerActions = 0
        nextSpacingIndex = 0
        show(.goal)
    }

    func stop() {
        isActive = false
        currentOverlay = nil
        activeDemo = nil
        highlightedCardIDs.removeAll()
        completedLessons.removeAll()
        awaitingPlayerAction = false
        demoLesson = nil
        playerActionsSinceLesson = 0
        totalPlayerActions = 0
        nextSpacingIndex = 0
    }

    func dismissCurrentOverlay() {
        dismissCurrentOverlay(engine: nil)
    }

    func dismissCurrentOverlay(engine: GameEngine?) {
        guard let overlay = currentOverlay else { return }
        currentOverlay = nil
        completedLessons.insert(overlay.lesson)

        if overlay.lesson == .goal {
            show(.swapBeforePlay)
            return
        }

        if overlay.lesson == .lowestStarts {
            show(.centerPile, engine: engine)
            return
        }

        if overlay.lesson == .centerPile {
            show(.playCards, engine: engine)
            return
        }

        if let demoKind = overlay.lesson.demoKind {
            demoLesson = overlay.lesson
            let cards = targetCards(for: overlay.lesson, engine: engine)
            activeDemo = TutorialDemo(
                kind: demoKind,
                cards: cards,
                topCard: engine?.state.topCard,
                repeatsUntilPlayerAction: overlay.lesson == .playCards
            )
            highlightedCardIDs = Set(cards.map(\.uid))
            awaitingPlayerAction = overlay.lesson == .playCards
        }
    }

    func finishActiveDemo() {
        guard let lesson = demoLesson else {
            activeDemo = nil
            return
        }
        activeDemo = nil
        demoLesson = nil
        if lesson == .swapBeforePlay {
            highlightedCardIDs.removeAll()
            awaitingPlayerAction = false
        } else if lesson != .playCards {
            awaitingPlayerAction = true
        }
    }

    func markPlayerActed() {
        if activeDemo?.repeatsUntilPlayerAction == true {
            activeDemo = nil
            demoLesson = nil
        }
        awaitingPlayerAction = false
        highlightedCardIDs.removeAll()
        playerActionsSinceLesson += 1
        totalPlayerActions += 1
    }

    func highlightedPlayableGroup(tapped card: Card, engine: GameEngine) -> [Card]? {
        guard highlightedCardIDs.contains(card.uid),
              let human = engine.state.players.first(where: { !$0.isAI })
        else { return nil }

        let group = human.activeCards.filter {
            highlightedCardIDs.contains($0.uid) &&
            $0.rank == card.rank &&
            engine.canPlay($0)
        }
        return group.count > 1 ? group : nil
    }

    func highlightedPlayableGroup(engine: GameEngine) -> [Card]? {
        guard let human = engine.state.players.first(where: { !$0.isAI }),
              let firstHighlighted = human.activeCards.first(where: { highlightedCardIDs.contains($0.uid) })
        else { return nil }
        return highlightedPlayableGroup(tapped: firstHighlighted, engine: engine)
    }

    func showNextLessonIfNeeded(engine: GameEngine) {
        guard isActive,
              currentOverlay == nil,
              activeDemo == nil,
              !awaitingPlayerAction,
              engine.state.phase == .playing,
              let human = engine.state.players.first(where: { !$0.isAI }),
              !engine.state.currentPlayer.isAI
        else { return }

        if let pendingJoker = engine.pendingJokerPlayerIndex {
            if !engine.state.players[pendingJoker].isAI,
               completedLessons.contains(.joker),
               !completedLessons.contains(.jokerStrategy) {
                show(.jokerStrategy, engine: engine)
            }
            return
        }

        if !completedLessons.contains(.lowestStarts) {
            show(.lowestStarts, engine: engine)
            return
        }

        if !completedLessons.contains(.centerPile) {
            show(.centerPile, engine: engine)
            return
        }

        if !completedLessons.contains(.playCards) {
            show(.playCards, engine: engine)
            return
        }

        for lesson in orderedGameplayLessons {
            guard !completedLessons.contains(lesson),
                  isLessonAvailable(lesson, human: human, engine: engine)
            else { continue }
            if shouldWaitBeforeShowing(lesson) {
                return
            }
            show(lesson, engine: engine)
            return
        }
    }

    private var orderedGameplayLessons: [TutorialLesson] {
        [
            .specialTwo,
            .specialTen,
            .lowestPlayableTip,
            .specialSeven,
            .specialEight,
            .specialNine,
            .joker,
            .queenTrapExpert,
            .pickupPile,
            .matchingCards,
            .fourOfKind,
            .faceUpCards,
            .jokerBeforeTenExpert,
            .faceDownCards
        ]
    }

    private func isLessonAvailable(_ lesson: TutorialLesson, human: Player, engine: GameEngine) -> Bool {
        let playable = engine.playableCards(for: human)
        switch lesson {
        case .goal, .swapBeforePlay, .lowestStarts, .centerPile, .playCards, .jokerStrategy:
            return false
        case .lowestPlayableTip:
            return totalPlayerActions >= 3
        case .matchingCards:
            let grouped = Dictionary(grouping: playable) { $0.rank }
            return grouped.values.contains { $0.count >= 2 }
        case .pickupPile:
            return playable.isEmpty && !engine.state.pile.isEmpty
        case .specialTwo:
            return playable.contains { $0.rank == .two }
        case .specialSeven:
            return playable.contains { $0.rank == .seven }
        case .specialEight:
            return playable.contains { $0.rank == .eight }
        case .specialNine:
            return playable.contains { $0.rank == .nine }
        case .specialTen:
            return !engine.state.pile.isEmpty &&
                playable.contains { $0.rank == .ten } &&
                playable.allSatisfy { $0.rank == .ten }
        case .joker:
            return !engine.state.pile.isEmpty && playable.contains { $0.rank == .joker }
        case .queenTrapExpert:
            return completedLessons.contains(.jokerStrategy) &&
                totalPlayerActions >= 8 &&
                canPrepareQueenTrapScenario(engine: engine)
        case .fourOfKind:
            guard let topCard = engine.state.topCard else { return false }
            let topCount = engine.state.pile.suffix(3).filter { $0.rank == topCard.rank }.count
            return topCount >= 3 && playable.contains { $0.rank == topCard.rank }
        case .faceUpCards:
            return human.playingFrom == .faceUp
        case .jokerBeforeTenExpert:
            return completedLessons.contains(.faceUpCards) &&
                canPrepareJokerBeforeTenScenario(engine: engine)
        case .faceDownCards:
            return human.playingFrom == .faceDown
        }
    }

    private func shouldWaitBeforeShowing(_ lesson: TutorialLesson) -> Bool {
        if lesson == .lowestPlayableTip ||
            lesson == .queenTrapExpert ||
            lesson == .jokerBeforeTenExpert ||
            lesson == .faceUpCards ||
            lesson == .faceDownCards {
            return false
        }
        return playerActionsSinceLesson < lessonSpacings[nextSpacingIndex % lessonSpacings.count]
    }

    private func show(_ lesson: TutorialLesson, engine: GameEngine? = nil) {
        if let engine {
            prepareScenarioIfNeeded(for: lesson, engine: engine)
        }
        currentOverlay = TutorialOverlayContent(lesson: lesson)
        playerActionsSinceLesson = 0
        if orderedGameplayLessons.contains(lesson) {
            nextSpacingIndex += 1
        }
        highlightedCardIDs = Set(targetCards(for: lesson, engine: engine).map(\.uid))
    }

    private func targetCards(for lesson: TutorialLesson, engine: GameEngine?) -> [Card] {
        guard let engine,
              let human = engine.state.players.first(where: { !$0.isAI })
        else { return [] }

        let playable = engine.playableCards(for: human)
        switch lesson {
        case .lowestStarts:
            if let openingCard = engine.openingCard,
               human.hand.contains(openingCard) {
                return [openingCard]
            }
            return human.hand.filter { $0.rank != .two && $0.rank != .joker }.prefixArray(1)
        case .playCards:
            if let openingCard = engine.openingCard,
               playable.contains(openingCard) {
                return [openingCard]
            }
            return preferredNormalPlayable(from: playable).map { [$0] } ?? Array(playable.prefix(1))
        case .centerPile:
            return []
        case .lowestPlayableTip:
            return []
        case .specialTwo:
            return playable.filter { $0.rank == .two }.prefixArray(1)
        case .specialSeven:
            return playable.filter { $0.rank == .seven }.prefixArray(1)
        case .specialEight:
            return playable.filter { $0.rank == .eight }.prefixArray(1)
        case .specialNine:
            return playable.filter { $0.rank == .nine }.prefixArray(1)
        case .specialTen:
            return playable.filter { $0.rank == .ten }.prefixArray(1)
        case .joker:
            return playable.filter { $0.rank == .joker }.prefixArray(1)
        case .queenTrapExpert:
            return playable.filter { $0.rank == .queen }.prefixArray(1)
        case .matchingCards:
            let grouped = Dictionary(grouping: playable) { $0.rank }
            return grouped.values.first(where: { $0.count >= 2 }) ?? []
        case .fourOfKind:
            guard let topCard = engine.state.topCard else { return [] }
            return playable.filter { $0.rank == topCard.rank }.prefixArray(1)
        case .faceUpCards:
            return human.faceUp.filter { playable.contains($0) }.prefixArray(1)
        case .jokerBeforeTenExpert:
            return human.faceUp.filter { $0.rank == .joker && playable.contains($0) }.prefixArray(1)
        case .faceDownCards:
            return human.faceDown.prefixArray(1)
        case .swapBeforePlay:
            let handCard = human.hand.first { $0.rank == .two }
                ?? human.hand.first { $0.rank == .joker }
                ?? human.hand.first
            let tableCard = human.faceUp.first { $0.rank == .ten }
                ?? human.faceUp.first { $0.rank.rawValue >= Rank.jack.rawValue }
                ?? human.faceUp.first
            return [handCard, tableCard].compactMap { $0 }
        case .goal, .pickupPile, .jokerStrategy:
            return []
        }
    }

    private func preferredNormalPlayable(from playable: [Card]) -> Card? {
        playable.first {
            !$0.isWild && !$0.isBurn && !$0.isJoker && !$0.isSeven && !$0.isSkip && !$0.isReverse
        }
    }

    private func prepareScenarioIfNeeded(for lesson: TutorialLesson, engine: GameEngine) {
        switch lesson {
        case .queenTrapExpert:
            prepareQueenTrapScenario(engine: engine)
        case .jokerBeforeTenExpert:
            prepareJokerBeforeTenScenario(engine: engine)
        default:
            break
        }
    }

    private func canPrepareQueenTrapScenario(engine: GameEngine) -> Bool {
        guard let humanIndex = humanIndex(in: engine),
              engine.state.currentPlayerIndex == humanIndex,
              nextPlayerIndex(from: humanIndex, in: engine).map({ engine.state.players[$0].isAI }) == true
        else { return false }
        return engine.pendingJokerPlayerIndex == nil
    }

    private func prepareQueenTrapScenario(engine: GameEngine) {
        guard canPrepareQueenTrapScenario(engine: engine),
              let humanIndex = humanIndex(in: engine),
              let nextIndex = nextPlayerIndex(from: humanIndex, in: engine)
        else { return }

        engine.openingCard = nil
        engine.mustPlayUnderSeven = false
        engine.state.pile = [Card(suit: .clubs, rank: .five)]
        engine.state.players[humanIndex].hand = GameRules.sortPlayableOrder([
            Card(suit: .clubs, rank: .six),
            Card(suit: .spades, rank: .nine),
            Card(suit: .hearts, rank: .queen)
        ])
        engine.state.players[humanIndex].drawPile.removeAll()
        engine.state.players[nextIndex].hand.removeAll()
        engine.state.players[nextIndex].drawPile.removeAll()
        engine.state.players[nextIndex].faceUp = [Card(suit: .hearts, rank: .jack)]
        if engine.state.players[nextIndex].faceDown.isEmpty {
            engine.state.players[nextIndex].faceDown = [Card(suit: .spades, rank: .king)]
        }
        engine.message = "Your turn"
    }

    private func canPrepareJokerBeforeTenScenario(engine: GameEngine) -> Bool {
        guard let humanIndex = humanIndex(in: engine),
              engine.state.currentPlayerIndex == humanIndex
        else { return false }
        return engine.pendingJokerPlayerIndex == nil
    }

    private func prepareJokerBeforeTenScenario(engine: GameEngine) {
        guard canPrepareJokerBeforeTenScenario(engine: engine),
              let humanIndex = humanIndex(in: engine)
        else { return }

        engine.openingCard = nil
        engine.mustPlayUnderSeven = false
        engine.state.pile = [
            Card(suit: .clubs, rank: .six),
            Card(suit: .diamonds, rank: .eight)
        ]
        engine.state.players[humanIndex].hand.removeAll()
        engine.state.players[humanIndex].drawPile.removeAll()
        engine.state.players[humanIndex].faceUp = [
            Card(suit: .spades, rank: .joker),
            Card(suit: .hearts, rank: .ten)
        ]
        engine.message = "Your turn"
    }

    private func humanIndex(in engine: GameEngine) -> Int? {
        engine.state.players.firstIndex { !$0.isAI }
    }

    private func nextPlayerIndex(from playerIndex: Int, in engine: GameEngine) -> Int? {
        let count = engine.state.players.count
        guard count > 1 else { return nil }

        for step in 1..<count {
            let next = ((playerIndex + engine.state.playDirection * step) % count + count) % count
            if engine.state.players[next].hasCards {
                return next
            }
        }
        return nil
    }
}

private extension Array {
    func prefixArray(_ maxLength: Int) -> [Element] {
        Array(prefix(maxLength))
    }
}

struct TutorialCoachOverlay: View {
    let content: TutorialOverlayContent
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture(perform: onContinue)

            VStack(spacing: 12) {
                GoldShimmerText(
                    text: content.title.uppercased(),
                    font: .system(size: 22, weight: .black, design: .serif)
                )

                Text(content.message)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let tipTitle = content.tipTitle,
                   let tipMessage = content.tipMessage {
                    VStack(spacing: 5) {
                        Rectangle()
                            .fill(Color.white.opacity(0.14))
                            .frame(height: 1)
                            .padding(.horizontal, 8)

                        Text(tipTitle.uppercased())
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.96, green: 0.76, blue: 0.32))

                        Text(tipMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                }

                PrimaryGameButton(
                    width: 128,
                    height: 38,
                    cornerRadius: 10,
                    shadowRadius: 6,
                    shadowY: 2,
                    action: onContinue
                ) {
                    Text(content.buttonTitle)
                        .font(.system(size: 15, weight: .black, design: .serif))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: 430)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.70))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(red: 0.96, green: 0.76, blue: 0.32).opacity(0.35), lineWidth: 1)
                    )
            )
            .padding(24)
        }
    }
}

struct TutorialDemoOverlay: View {
    let demo: TutorialDemo

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(demo.repeatsUntilPlayerAction ? 0.08 : 0.14)
                .ignoresSafeArea()

            Text(caption)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.black.opacity(0.58)))
                .padding(.bottom, 30)
        }
        .allowsHitTesting(!demo.repeatsUntilPlayerAction)
    }

    private var primaryCard: Card {
        demo.cards.first ?? Card(suit: .hearts, rank: .king)
    }

    private var caption: String {
        switch demo.kind {
        case .swap: return "Tap one hand card, then one table card."
        case .playCard:
            if let topCard = demo.topCard {
                return "Play \(primaryCard.rank.label) on the \(topCard.rank.label) in the center pile."
            }
            return "Double tap or drag a playable card to the pile."
        case .multiCard: return "Select matching cards, then play the group."
        case .pickup: return "Use Pick Up when no card can play."
        case .faceDown: return "Tap a face-down card to try it."
        case .reverse: return "A 9 reverses the play direction."
        }
    }
}
