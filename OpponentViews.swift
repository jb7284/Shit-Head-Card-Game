import SwiftUI

struct AvatarView: View {
    let avatar: String
    let size: CGFloat

    private var isImage: Bool {
        avatar.hasPrefix("avatar_")
    }

    var body: some View {
        if isImage {
            Image(avatar)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if !avatar.isEmpty {
            Text(avatar)
                .font(.system(size: size * 0.7))
        }
    }
}

struct TopOpponentView: View {
    let player: Player
    let active: Bool
    let isNext: Bool
    let turnPulse: Bool

    @Environment(\.gameScale) private var gs

    var body: some View {
        HStack(alignment: .top, spacing: 8 * gs) {
            VStack(spacing: 2 * gs) {
                AvatarView(avatar: player.avatar, size: 80 * gs)
                Text(player.name)
                    .font(.system(size: 12 * gs, weight: .bold))
                    .foregroundStyle(.white.opacity(active ? 0.9 : 0.5))
                if !player.hasCards {
                    Text("OUT")
                        .font(.system(size: 8 * gs, weight: .heavy))
                        .foregroundStyle(.green)
                }
                if isNext && player.hasCards {
                    Text("Next")
                        .font(.system(size: 8 * gs, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            VStack(alignment: .leading, spacing: 4 * gs) {
                OpponentHandFan(cards: player.hand, avatarSize: 80 * gs)
                    .opacity(active ? 1.0 : 0.5)

                HStack(spacing: 3 * gs) {
                    ForEach(0..<3, id: \.self) { i in
                        ZStack {
                            if i < player.faceDown.count {
                                OpponentCardView()
                            }
                            if i < player.faceUp.count {
                                OpponentCardView(card: player.faceUp[i])
                                    .offset(y: -8 * gs)
                            }
                        }
                    }

                    if player.drawPile.count > 0 {
                        DrawPileStack(count: player.drawPile.count, mini: true)
                            .padding(.leading, 6 * gs)
                    }
                }
                .opacity(active ? 1.0 : 0.5)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: active)
    }
}

struct SideOpponentView: View {
    let player: Player
    let active: Bool
    let isNext: Bool
    let turnPulse: Bool

    @Environment(\.gameScale) private var gs

    var body: some View {
        HStack(alignment: .top, spacing: 6 * gs) {
            VStack(spacing: 2 * gs) {
                AvatarView(avatar: player.avatar, size: 84 * gs)
                Text(player.name)
                    .font(.system(size: 12 * gs, weight: .bold))
                    .foregroundStyle(.white.opacity(active ? 0.9 : 0.5))
                if !player.hasCards {
                    Text("OUT")
                        .font(.system(size: 8 * gs, weight: .heavy))
                        .foregroundStyle(.green)
                }
                if isNext && player.hasCards {
                    Text("Next")
                        .font(.system(size: 8 * gs, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            VStack(spacing: 4 * gs) {
                OpponentHandFan(cards: player.hand, avatarSize: 84 * gs)
                    .opacity(active ? 1.0 : 0.5)

                VStack(spacing: 3 * gs) {
                    ForEach(0..<3, id: \.self) { i in
                        ZStack {
                            if i < player.faceDown.count {
                                OpponentCardView()
                            }
                            if i < player.faceUp.count {
                                OpponentCardView(card: player.faceUp[i])
                                    .offset(x: 8 * gs)
                            }
                        }
                    }

                    if player.drawPile.count > 0 {
                        DrawPileStack(count: player.drawPile.count, mini: true)
                            .padding(.top, 4 * gs)
                    }
                }
                .opacity(active ? 1.0 : 0.5)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: active)
    }
}

struct OpponentHandFan: View {
    let cards: [Card]
    let avatarSize: CGFloat

    @Environment(\.gameScale) private var gs

    private var cardWidth: CGFloat { 30 * gs }
    private var cardHeight: CGFloat { 40 * gs }

    private var baseOverlap: CGFloat {
        let n = cards.count
        if n <= 6 { return 0.40 }
        if n >= 15 { return 0.70 }
        let t = CGFloat(n - 6) / 9
        return 0.40 + (0.70 - 0.40) * t
    }

    private var widthCap: CGFloat { avatarSize * 2.5 }

    private var advance: CGFloat {
        guard cards.count > 1 else { return 0 }
        let baseAdvance = cardWidth * (1 - baseOverlap)
        let baseTotal = cardWidth + baseAdvance * CGFloat(cards.count - 1)
        if baseTotal <= widthCap { return baseAdvance }
        return max(0, (widthCap - cardWidth) / CGFloat(cards.count - 1))
    }

    private var totalWidth: CGFloat {
        guard !cards.isEmpty else { return 0 }
        return cardWidth + advance * CGFloat(cards.count - 1)
    }

    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.uid) { index, _ in
                OpponentCardView()
                    .offset(x: CGFloat(index) * advance - totalWidth / 2 + cardWidth / 2)
            }
        }
        .frame(width: totalWidth, height: cardHeight)
    }
}

struct OpponentCardView: View {
    var card: Card? = nil

    @Environment(\.gameScale) private var gs
    private var isVisible: Bool { card != nil }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4 * gs)
                .fill(isVisible ? Color(white: 0.95) : Color(red: 0.50, green: 0.38, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 4 * gs)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
            if let card {
                VStack(spacing: -1 * gs) {
                    Text(card.rank.label)
                        .font(.system(size: 14 * gs, weight: .bold, design: .serif))
                    Text(card.suit.character)
                        .font(.system(size: 11 * gs))
                }
                .foregroundStyle(card.suit == .hearts || card.suit == .diamonds
                                 ? Color(red: 0.8, green: 0.1, blue: 0.1)
                                 : Color(red: 0.1, green: 0.1, blue: 0.15))
            }
        }
        .frame(width: 30 * gs, height: 40 * gs)
    }
}

struct MiniCardView: View {
    var card: Card? = nil

    private var isVisible: Bool { card != nil }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isVisible ? Color(white: 0.95) : Color(red: 0.50, green: 0.38, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            if let card {
                HStack(spacing: 1) {
                    Text(card.rank.label)
                        .font(.system(size: 8, weight: .bold, design: .serif))
                    Text(card.suit.character)
                        .font(.system(size: 7))
                }
                .foregroundStyle(card.suit == .hearts || card.suit == .diamonds
                                 ? Color(red: 0.8, green: 0.1, blue: 0.1)
                                 : Color(red: 0.1, green: 0.1, blue: 0.15))
            }
        }
        .frame(width: 24, height: 18)
    }
}

// MARK: - Programmatic Character Avatars

struct CharacterAvatar: View {
    let style: AvatarStyle
    let size: CGFloat

    enum AvatarStyle {
        case blaze, ace, bones, lucky, shadow
    }

    var body: some View {
        ZStack {
            Circle().fill(skinColor)
            features
            if style != .ace { eyes }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
    }

    private var skinColor: Color {
        switch style {
        case .blaze: return Color(red: 0.93, green: 0.73, blue: 0.53)
        case .ace: return Color(red: 0.88, green: 0.78, blue: 0.70)
        case .bones: return Color(red: 0.82, green: 0.82, blue: 0.86)
        case .lucky: return Color(red: 0.90, green: 0.76, blue: 0.62)
        case .shadow: return Color(red: 0.50, green: 0.38, blue: 0.30)
        }
    }

    private var eyes: some View {
        HStack(spacing: size * 0.18) {
            Circle().fill(Color(red: 0.18, green: 0.14, blue: 0.1))
                .frame(width: size * 0.13, height: size * 0.13)
            Circle().fill(Color(red: 0.18, green: 0.14, blue: 0.1))
                .frame(width: size * 0.13, height: size * 0.13)
        }
        .offset(y: size * 0.02)
    }

    @ViewBuilder
    private var features: some View {
        switch style {
        case .blaze:
            ZStack {
                Ellipse()
                    .fill(Color(red: 1.0, green: 0.45, blue: 0.1))
                    .frame(width: size * 0.75, height: size * 0.35)
                    .offset(y: -size * 0.28)
                ForEach(0..<3, id: \.self) { i in
                    Ellipse()
                        .fill(Color(red: 1.0, green: 0.3, blue: 0.0))
                        .frame(width: size * 0.16, height: size * 0.3)
                        .offset(x: CGFloat(i - 1) * size * 0.2, y: -size * 0.42)
                }
            }
        case .ace:
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.1, green: 0.08, blue: 0.14))
                    .frame(width: size * 0.8, height: size * 0.35)
                    .offset(y: -size * 0.28)
                RoundedRectangle(cornerRadius: size * 0.04)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.1))
                    .frame(width: size * 0.58, height: size * 0.14)
                    .offset(y: size * 0.0)
            }
        case .bones:
            HStack(spacing: size * 0.1) {
                Circle()
                    .fill(Color(red: 0.18, green: 0.18, blue: 0.22))
                    .frame(width: size * 0.24, height: size * 0.24)
                    .overlay(
                        Circle().fill(Color(red: 0.82, green: 0.82, blue: 0.86))
                            .frame(width: size * 0.08, height: size * 0.08)
                    )
                Circle()
                    .fill(Color(red: 0.18, green: 0.18, blue: 0.22))
                    .frame(width: size * 0.24, height: size * 0.24)
                    .overlay(
                        Circle().fill(Color(red: 0.82, green: 0.82, blue: 0.86))
                            .frame(width: size * 0.08, height: size * 0.08)
                    )
            }
            .offset(y: -size * 0.02)
        case .lucky:
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.15, green: 0.55, blue: 0.2))
                    .frame(width: size * 0.85, height: size * 0.18)
                    .offset(y: -size * 0.14)
                Ellipse()
                    .fill(Color(red: 0.18, green: 0.62, blue: 0.25))
                    .frame(width: size * 0.7, height: size * 0.4)
                    .offset(y: -size * 0.32)
            }
        case .shadow:
            Ellipse()
                .fill(Color(red: 0.1, green: 0.07, blue: 0.18))
                .frame(width: size * 0.95, height: size * 0.7)
                .offset(y: -size * 0.18)
        }
    }
}

#Preview("Opponent Layout") {
    let mockCards: [Card] = [
        Card(suit: .hearts, rank: .jack),
        Card(suit: .spades, rank: .two),
        Card(suit: .hearts, rank: .queen)
    ]
    let mockDown: [Card] = [
        Card(suit: .clubs, rank: .three),
        Card(suit: .diamonds, rank: .five),
        Card(suit: .spades, rank: .nine)
    ]
    let mockDraw: [Card] = Array(repeating: Card(suit: .clubs, rank: .ace), count: 8)
    let mockHand: [Card] = [
        Card(suit: .diamonds, rank: .king),
        Card(suit: .clubs, rank: .seven),
        Card(suit: .hearts, rank: .four)
    ]

    func mockPlayer(_ name: String, _ avatar: String, id: String) -> Player {
        var p = Player(id: id, name: name, avatar: avatar, isAI: true)
        p.faceUp = mockCards
        p.faceDown = mockDown
        p.drawPile = mockDraw
        p.hand = mockHand
        return p
    }

    let marco = mockPlayer("Marco", "avatar_marco", id: "ai0")
    let sofia = mockPlayer("Sofia", "avatar_sofia", id: "ai1")
    let dante = mockPlayer("Dante", "avatar_dante", id: "ai2")
    let ava = mockPlayer("Ava", "avatar_ava", id: "ai3")
    let jake = mockPlayer("Jake", "avatar_jake", id: "ai4")

    return ZStack {
        Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea()
        VStack(spacing: 20) {
            Text("Top Opponents").font(.caption).foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 12) {
                TopOpponentView(player: marco, active: true, isNext: false, turnPulse: true)
                TopOpponentView(player: sofia, active: false, isNext: true, turnPulse: false)
                TopOpponentView(player: dante, active: false, isNext: false, turnPulse: false)
            }

            Text("Side Opponents").font(.caption).foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 20) {
                SideOpponentView(player: ava, active: true, isNext: false, turnPulse: true)
                SideOpponentView(player: jake, active: false, isNext: true, turnPulse: false)
            }
        }
    }
}

// MARK: - Draw Pile

struct DrawPileStack: View {
    let count: Int
    let mini: Bool

    @Environment(\.gameScale) private var gs

    private var cardW: CGFloat { (mini ? 30 : 38) * gs }
    private var cardH: CGFloat { (mini ? 40 : 54) * gs }
    private var radius: CGFloat { (mini ? 4 : 5) * gs }
    private var fontSize: CGFloat { (mini ? 9 : 12) * gs }
    private var stackOff: CGFloat { (mini ? 1.5 : 2) * gs }

    var body: some View {
        let layers = min(count, 4)
        ZStack {
            ForEach(0..<layers, id: \.self) { i in
                RoundedRectangle(cornerRadius: radius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.42, blue: 0.18),
                                Color(red: 0.40, green: 0.30, blue: 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.78, green: 0.66, blue: 0.34).opacity(0.5),
                                        Color(red: 0.50, green: 0.38, blue: 0.18).opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.7
                            )
                    )
                    .frame(width: cardW, height: cardH)
                    .shadow(color: .black.opacity(0.4), radius: 2 * gs, x: 1 * gs, y: 2 * gs)
                    .offset(x: CGFloat(i) * stackOff, y: CGFloat(-i) * stackOff)
            }

            Text("\(count)")
                .font(.system(size: fontSize, weight: .black, design: .serif))
                .foregroundStyle(Color(red: 0.95, green: 0.85, blue: 0.55))
                .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
        }
    }
}
