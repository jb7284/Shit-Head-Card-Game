import Foundation

enum GameRules {
    static func canPlay(_ card: Card, effectiveTopCard: Card?, mustPlayUnderSeven: Bool) -> Bool {
        if card.isWild || card.isBurn { return true }

        if mustPlayUnderSeven {
            return card.rank <= .seven
        }

        guard let top = effectiveTopCard else { return true }
        return card.rank >= top.rank
    }

    static func isFourOfAKindBurn(pile: [Card], triggerCard: Card) -> Bool {
        guard pile.count >= 4 else { return false }
        return pile.suffix(4).allSatisfy { $0.rank == triggerCard.rank }
    }

    static func faceUpDesirability(_ card: Card) -> Int {
        if card.isWild { return 20 }
        if card.isBurn { return 19 }
        return card.rank.rawValue
    }

    static func sortPlayableOrder(_ cards: [Card]) -> [Card] {
        cards.sorted { $0.rank < $1.rank }
    }
}
