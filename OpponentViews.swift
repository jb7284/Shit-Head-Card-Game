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

// MARK: - Shared Opponent Identity

private struct OpponentIdentityView: View {
    let player: Player
    let active: Bool
    let isNext: Bool
    let avatarSize: CGFloat

    @Environment(\.gameScale) private var gs

    var body: some View {
        VStack(spacing: 2 * gs) {
            AvatarView(avatar: player.avatar, size: avatarSize)
                .brightness(active ? 0 : -0.18)
                .saturation(active ? 1 : 0.65)
                .contrast(active ? 1 : 0.92)
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
    }
}

// MARK: - Skipped Overlay Modifier

private struct SkippedOverlayModifier: ViewModifier {
    let playerID: String
    let skippedPlayerID: String?

    func body(content: Content) -> some View {
        content.overlay {
            if skippedPlayerID == playerID {
                SkippedBadge()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }
}

private struct InactiveOpponentCardsModifier: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .brightness(active ? 0 : -0.34)
            .saturation(active ? 1 : 0.48)
            .contrast(active ? 1 : 0.88)
    }
}

// MARK: - Top Opponent

struct TopOpponentView: View {
    let player: Player
    let active: Bool
    let isNext: Bool
    let turnPulse: Bool
    let skippedPlayerID: String?

    @Environment(\.gameScale) private var gs

    var body: some View {
        HStack(alignment: .top, spacing: 8 * gs) {
            OpponentIdentityView(player: player, active: active, isNext: isNext, avatarSize: 80 * gs)

            VStack(alignment: .leading, spacing: 4 * gs) {
                OpponentHandFan(cards: player.hand, avatarSize: 80 * gs, playerID: player.id)
                    .modifier(InactiveOpponentCardsModifier(active: active))

                HStack(spacing: 3 * gs) {
                    ForEach(0..<3, id: \.self) { i in
                        ZStack {
                            if i < player.faceDown.count {
                                OpponentCardView()
                                    .reportCardFrame(player.faceDown[i].uid)
                                    .hideIfInFlight(player.faceDown[i].uid)
                            }
                            if i < player.faceUp.count {
                                OpponentCardView(card: player.faceUp[i])
                                    .reportCardFrame(player.faceUp[i].uid)
                                    .hideIfInFlight(player.faceUp[i].uid)
                                    .offset(y: -8 * gs)
                            }
                        }
                    }

                    if player.drawPile.count > 0 {
                        DrawPileStack(count: player.drawPile.count, mini: true)
                            .reportDrawPileFrame(player.id)
                            .padding(.leading, 6 * gs)
                    }
                }
                .modifier(InactiveOpponentCardsModifier(active: active))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: active)
        .modifier(SkippedOverlayModifier(playerID: player.id, skippedPlayerID: skippedPlayerID))
    }
}

// MARK: - Side Opponent

struct SideOpponentView: View {
    let player: Player
    let active: Bool
    let isNext: Bool
    let turnPulse: Bool
    let skippedPlayerID: String?

    @Environment(\.gameScale) private var gs

    var body: some View {
        HStack(alignment: .center, spacing: 8 * gs) {
            OpponentIdentityView(player: player, active: active, isNext: isNext, avatarSize: 84 * gs)

            SideOpponentHandFan(cards: player.hand, avatarSize: 84 * gs, playerID: player.id)
                .modifier(InactiveOpponentCardsModifier(active: active))

            tableCards
                .modifier(InactiveOpponentCardsModifier(active: active))
        }
        .animation(.easeInOut(duration: 0.3), value: active)
        .modifier(SkippedOverlayModifier(playerID: player.id, skippedPlayerID: skippedPlayerID))
    }

    private var tableCards: some View {
        VStack(spacing: 3 * gs) {
            ForEach(0..<3, id: \.self) { i in
                ZStack {
                    if i < player.faceDown.count {
                        OpponentCardView()
                            .reportCardFrame(player.faceDown[i].uid)
                            .hideIfInFlight(player.faceDown[i].uid)
                    }
                    if i < player.faceUp.count {
                        OpponentCardView(card: player.faceUp[i])
                            .reportCardFrame(player.faceUp[i].uid)
                            .hideIfInFlight(player.faceUp[i].uid)
                            .offset(x: 8 * gs)
                    }
                }
            }

            if player.drawPile.count > 0 {
                DrawPileStack(count: player.drawPile.count, mini: true)
                    .reportDrawPileFrame(player.id)
                    .padding(.top, 4 * gs)
            }
        }
    }
}

// MARK: - Fan Overlap

private func fanOverlap(cardCount: Int) -> CGFloat {
    let n = cardCount
    if n <= 6 { return 0.40 }
    if n >= 15 { return 0.70 }
    let t = CGFloat(n - 6) / 9
    return 0.40 + (0.70 - 0.40) * t
}

// MARK: - Hand Fans

struct OpponentHandFan: View {
    let cards: [Card]
    let avatarSize: CGFloat
    let playerID: String

    @Environment(\.gameScale) private var gs

    private var cardWidth: CGFloat { 30 * gs }
    private var cardHeight: CGFloat { 40 * gs }
    private var widthCap: CGFloat { avatarSize * 2.5 }

    private var advance: CGFloat {
        guard cards.count > 1 else { return 0 }
        let baseAdvance = cardWidth * (1 - fanOverlap(cardCount: cards.count))
        let baseTotal = cardWidth + baseAdvance * CGFloat(cards.count - 1)
        if baseTotal <= widthCap { return baseAdvance }
        return max(0, (widthCap - cardWidth) / CGFloat(cards.count - 1))
    }

    private var totalWidth: CGFloat {
        guard !cards.isEmpty else { return cardWidth }
        return cardWidth + advance * CGFloat(cards.count - 1)
    }

    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.uid) { index, card in
                OpponentCardView()
                    .reportCardFrame(card.uid)
                    .hideIfInFlight(card.uid)
                    .offset(x: CGFloat(index) * advance - totalWidth / 2 + cardWidth / 2)
            }
        }
        .frame(width: max(totalWidth, cardWidth), height: cardHeight)
        .reportHandCenter(playerID)
    }
}

struct SideOpponentHandFan: View {
    let cards: [Card]
    let avatarSize: CGFloat
    let playerID: String

    @Environment(\.gameScale) private var gs

    private var cardWidth: CGFloat { 30 * gs }
    private var cardHeight: CGFloat { 40 * gs }
    private var heightCap: CGFloat { avatarSize * 1.9 }

    private var advance: CGFloat {
        guard cards.count > 1 else { return 0 }
        let baseAdvance = cardWidth * (1 - fanOverlap(cardCount: cards.count))
        let baseTotal = cardWidth + baseAdvance * CGFloat(cards.count - 1)
        if baseTotal <= heightCap { return baseAdvance }
        return max(0, (heightCap - cardWidth) / CGFloat(cards.count - 1))
    }

    private var totalHeight: CGFloat {
        guard !cards.isEmpty else { return cardWidth }
        return cardWidth + advance * CGFloat(cards.count - 1)
    }

    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.uid) { index, card in
                OpponentCardView()
                    .reportCardFrame(card.uid)
                    .hideIfInFlight(card.uid)
                    .rotationEffect(.degrees(90))
                    .offset(y: CGFloat(index) * advance - totalHeight / 2 + cardWidth / 2)
            }
        }
        .frame(width: cardHeight, height: max(totalHeight, cardWidth))
        .reportHandCenter(playerID)
    }
}

// MARK: - Card Views

struct OpponentCardView: View {
    var card: Card? = nil

    var body: some View {
        CardView(
            card: card ?? Card(suit: .clubs, rank: .ace),
            faceUp: card != nil,
            small: true,
            style: .opponent
        )
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

// MARK: - Draw Pile

struct DrawPileStack: View {
    let count: Int
    let mini: Bool

    @Environment(\.gameScale) private var gs

    private var fontSize: CGFloat { (mini ? 9 : 12) * gs }
    private var stackOff: CGFloat { (mini ? 1.5 : 2) * gs }
    private var placeholderCard: Card { Card(suit: .clubs, rank: .ace) }

    var body: some View {
        let layers = min(count, 4)
        ZStack {
            ForEach(0..<layers, id: \.self) { i in
                CardView(
                    card: placeholderCard,
                    faceUp: false,
                    small: !mini,
                    style: mini ? .opponent : .standard
                )
                    .offset(x: CGFloat(i) * stackOff, y: CGFloat(-i) * stackOff)
            }

            Text("\(count)")
                .font(.system(size: fontSize, weight: .black, design: .serif))
                .foregroundStyle(Color(red: 0.95, green: 0.85, blue: 0.55))
                .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
        }
    }
}

struct SkippedBadge: View {
    @Environment(\.gameScale) private var gs

    var body: some View {
        Text("SKIPPED!")
            .font(.system(size: 16 * gs, weight: .black))
            .foregroundStyle(.green)
            .shadow(color: .black.opacity(0.8), radius: 4, y: 2)
            .shadow(color: .green.opacity(0.4), radius: 8)
            .allowsHitTesting(false)
    }
}
