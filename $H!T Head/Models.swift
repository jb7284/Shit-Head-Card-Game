import Foundation

// MARK: - Card

enum Suit: String, CaseIterable, Codable {
    case hearts, diamonds, clubs, spades

    var symbol: String {
        switch self {
        case .hearts: return "♥️"
        case .diamonds: return "♦️"
        case .clubs: return "♣️"
        case .spades: return "♠️"
        }
    }

    var character: String {
        switch self {
        case .hearts: return "\u{2665}"
        case .diamonds: return "\u{2666}"
        case .clubs: return "\u{2663}"
        case .spades: return "\u{2660}"
        }
    }
}

enum Rank: Int, CaseIterable, Codable, Comparable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace

    static func < (lhs: Rank, rhs: Rank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "10"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        }
    }
}

struct Card: Identifiable, Equatable, Codable {
    let uid: UUID
    let suit: Suit
    let rank: Rank

    init(suit: Suit, rank: Rank) {
        self.uid = UUID()
        self.suit = suit
        self.rank = rank
    }

    var id: UUID { uid }
    var display: String { "\(rank.label)\(suit.symbol)" }

    static func == (lhs: Card, rhs: Card) -> Bool {
        lhs.uid == rhs.uid
    }

    var isWild: Bool { rank == .two }
    var isBurn: Bool { rank == .ten }
    var isSeven: Bool { rank == .seven }
    var isSkip: Bool { rank == .eight }
    var isReverse: Bool { rank == .nine }
}

// MARK: - Deck

struct Deck {
    private(set) var cards: [Card]

    static func standard(deckCount: Int = 1) -> Deck {
        var cards: [Card] = []
        for _ in 0..<deckCount {
            for suit in Suit.allCases {
                for rank in Rank.allCases {
                    cards.append(Card(suit: suit, rank: rank))
                }
            }
        }
        return Deck(cards: cards.shuffled())
    }

    var isEmpty: Bool { cards.isEmpty }
    var count: Int { cards.count }

    mutating func draw() -> Card? {
        cards.isEmpty ? nil : cards.removeFirst()
    }

    mutating func draw(_ n: Int) -> [Card] {
        let count = min(n, cards.count)
        let drawn = Array(cards.prefix(count))
        cards.removeFirst(count)
        return drawn
    }
}

// MARK: - Player

struct Player: Identifiable {
    let id: String
    let name: String
    let avatar: String
    let isAI: Bool

    var hand: [Card] = []
    var faceUp: [Card] = []
    var faceDown: [Card] = []
    var drawPile: [Card] = []

    var hasCards: Bool {
        !hand.isEmpty || !drawPile.isEmpty || !faceUp.isEmpty || !faceDown.isEmpty
    }

    var activeCards: [Card] {
        if !hand.isEmpty { return hand }
        if !drawPile.isEmpty { return [] }
        if !faceUp.isEmpty { return faceUp }
        return faceDown
    }

    var playingFrom: CardZone {
        if !hand.isEmpty { return .hand }
        if !drawPile.isEmpty { return .hand }
        if !faceUp.isEmpty { return .faceUp }
        return .faceDown
    }
}

enum CardZone {
    case hand, faceUp, faceDown
}

// MARK: - Game State

enum GamePhase {
    case dealing
    case swapping
    case playing
    case finished
}

enum Difficulty: CaseIterable {
    case easy, medium, expert

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .expert: return "Expert"
        }
    }
}

@Observable
class GameState {
    var players: [Player] = []
    var pile: [Card] = []
    var deck: Deck = Deck(cards: [])
    var currentPlayerIndex: Int = 0
    var playDirection: Int = 1
    var phase: GamePhase = .dealing
    var turnNumber: Int = 0
    var finishOrder: [String] = []

    var currentPlayer: Player {
        players[currentPlayerIndex]
    }

    var topCard: Card? {
        pile.last
    }

    var effectiveTopCard: Card? {
        pile.last(where: { $0.rank != .seven }) ?? pile.last
    }

    var loser: Player? {
        guard phase == .finished else { return nil }
        return players.first(where: { $0.hasCards })
    }
}
