import SwiftUI

struct CardView: View {
    let card: Card
    let faceUp: Bool
    var highlight: Bool = false
    var selected: Bool = false
    var small: Bool = false
    var dimmed: Bool = false
    var style: CardViewStyle = .standard

    @Environment(\.gameScale) private var gs

    private var width: CGFloat { style.width(small: small) * gs }
    private var height: CGFloat { style.height(small: small) * gs }
    private var cornerRadius: CGFloat { style.cornerRadius(small: small) * gs }
    private var faceInset: CGFloat { (small ? 2.5 : 4) * gs }

    var body: some View {
        ZStack {
            if faceUp {
                cardFace
            } else {
                cardBack
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
        .brightness(dimmed ? -0.22 : 0)
        .saturation(dimmed ? 0.55 : 1)
        .offset(y: selected ? -14 * gs : 0)
        .scaleEffect(selected ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: selected)
        .animation(.easeInOut(duration: 0.2), value: dimmed)
    }

    // MARK: - Card Face

    private var cardFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.995, blue: 0.965),
                            Color(red: 0.98, green: 0.955, blue: 0.89),
                            Color(red: 0.93, green: 0.89, blue: 0.80)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            cardPaperTexture

            RoundedRectangle(cornerRadius: max(cornerRadius - faceInset, 1))
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.28),
                            .clear,
                            Color.black.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(faceInset)

            faceBorder

            if !small {
                diagonalSheen
            }

            if small {
                smallFaceContent
            } else {
                fullFaceContent
            }
        }
    }

    private var suitColor: Color {
        if card.isJoker {
            return Color(red: 0.80, green: 0.62, blue: 0.15)
        }
        return card.suit == .hearts || card.suit == .diamonds
            ? Color(red: 0.72, green: 0.04, blue: 0.05)
            : Color(red: 0.06, green: 0.06, blue: 0.08)
    }

    private var smallFaceContent: some View {
        VStack(spacing: 0) {
            if card.isJoker {
                Text("\u{1F0CF}")
                    .font(.system(size: 16 * gs))
            } else {
                Text(card.rank.label)
                    .font(.system(size: 11 * gs, weight: .bold, design: .serif))
                Text(card.suit.character)
                    .font(.system(size: 9 * gs))
            }
        }
        .foregroundStyle(suitColor)
    }

    private var fullFaceContent: some View {
        ZStack {
            cornerMark
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 5 * gs)
            .padding(.top, 4 * gs)

            cornerMark
            .rotationEffect(.degrees(180))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 5 * gs)
            .padding(.bottom, 4 * gs)

            centerPips
        }
    }

    private var cardPaperTexture: some View {
        Canvas { context, size in
            let speckColor = Color.black.opacity(0.025)
            for index in 0..<(small ? 16 : 36) {
                let xSeed = CGFloat((index * 37) % 100) / 100
                let ySeed = CGFloat((index * 61) % 100) / 100
                let rect = CGRect(
                    x: xSeed * size.width,
                    y: ySeed * size.height,
                    width: index.isMultiple(of: 3) ? 1.2 : 0.8,
                    height: 0.8
                )
                context.fill(Path(ellipseIn: rect), with: .color(speckColor))
            }
        }
        .opacity(small ? 0.35 : 0.65)
    }

    private var faceBorder: some View {
        RoundedRectangle(cornerRadius: max(cornerRadius - 1.5 * gs, 1))
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(0.55),
                        Color.black.opacity(0.10),
                        .white.opacity(0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: (small ? 0.75 : 1.1) * gs
            )
            .padding((small ? 2 : 3) * gs)
            .overlay(
                RoundedRectangle(cornerRadius: max(cornerRadius - 4 * gs, 1))
                    .stroke(suitColor.opacity(0.12), lineWidth: (small ? 0.35 : 0.55) * gs)
                    .padding((small ? 5 : 7) * gs)
            )
    }

    private var diagonalSheen: some View {
        LinearGradient(
            colors: [
                .white.opacity(0.24),
                .white.opacity(0.06),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blendMode(.screen)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var cornerMark: some View {
        VStack(spacing: -2 * gs) {
            if card.isJoker {
                Text("\u{2605}")
                    .font(.system(size: 12 * gs, weight: .heavy))
            } else {
                Text(card.rank.label)
                    .font(.system(size: 13 * gs, weight: .heavy, design: .serif))
                Text(card.suit.character)
                    .font(.system(size: 10 * gs, weight: .bold))
            }
        }
        .foregroundStyle(suitColor)
        .shadow(color: .white.opacity(0.45), radius: 0.5, y: 0.5)
    }

    @ViewBuilder
    private var centerPips: some View {
        if card.isJoker {
            OrnamentalJokerMark(scale: gs, color: suitColor)
        } else if card.rank.rawValue <= Rank.ten.rawValue {
            pipLayout
        } else {
            RoyalCardCenter(card: card, suitColor: suitColor, scale: gs)
        }
    }

    private var pipLayout: some View {
        VStack(spacing: 4 * gs) {
            ForEach(pipRows.indices, id: \.self) { rowIndex in
                HStack(spacing: 8 * gs) {
                    ForEach(0..<pipRows[rowIndex], id: \.self) { _ in
                        SuitPip(suit: card.suit, color: suitColor, size: pipFontSize * gs)
                    }
                }
                .rotationEffect(rowIndex > pipRows.count / 2 ? .degrees(180) : .zero)
            }
        }
    }

    private var pipRows: [Int] {
        switch card.rank {
        case .joker: return [1]
        case .two: return [1, 1]
        case .three: return [1, 1, 1]
        case .four: return [2, 2]
        case .five: return [2, 1, 2]
        case .six: return [2, 2, 2]
        case .seven: return [2, 1, 2, 2]
        case .eight: return [2, 2, 2, 2]
        case .nine: return [2, 2, 1, 2, 2]
        case .ten: return [2, 2, 2, 2, 2]
        default: return [1]
        }
    }

    private var pipFontSize: CGFloat {
        card.rank.rawValue >= Rank.nine.rawValue ? 9 : 11
    }

    // MARK: - Card Back

    private var cardBack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.68, green: 0.53, blue: 0.22),
                            Color(red: 0.39, green: 0.28, blue: 0.10),
                            Color(red: 0.18, green: 0.12, blue: 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.82, blue: 0.36).opacity(0.22),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: height * 0.9
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius - 1)
                .stroke(Color(red: 0.92, green: 0.76, blue: 0.36).opacity(0.55), lineWidth: (small ? 0.8 : 1.2) * gs)
                .padding(3 * gs)

            Canvas { context, size in
                let step: CGFloat = small ? 5 : 7
                let color = Color(red: 0.95, green: 0.78, blue: 0.36).opacity(0.13)
                for x in stride(from: -size.height, through: size.width + size.height, by: step) {
                    var downStroke = Path()
                    downStroke.move(to: CGPoint(x: x, y: 0))
                    downStroke.addLine(to: CGPoint(x: x - size.height, y: size.height))
                    context.stroke(downStroke, with: .color(color), lineWidth: 0.55 * gs)

                    var upStroke = Path()
                    upStroke.move(to: CGPoint(x: x, y: 0))
                    upStroke.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    context.stroke(upStroke, with: .color(color), lineWidth: 0.55 * gs)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 2))
            .padding(5 * gs)

            cardBackMonogram

            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.78, green: 0.66, blue: 0.34).opacity(0.45),
                            Color(red: 0.30, green: 0.22, blue: 0.10).opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        }
    }

    private var cardBackMonogram: some View {
        let markScale = width / (58 * gs)

        return ZStack {
            RoundedRectangle(cornerRadius: 8 * markScale * gs)
                .stroke(Color(red: 0.95, green: 0.78, blue: 0.36).opacity(0.24), lineWidth: 0.9 * markScale * gs)
                .frame(width: 34 * markScale * gs, height: 48 * markScale * gs)
            DiamondShape()
                .fill(Color(red: 0.90, green: 0.72, blue: 0.30).opacity(0.18))
                .frame(width: 25 * markScale * gs, height: 34 * markScale * gs)
            DiamondShape()
                .stroke(Color(red: 0.98, green: 0.82, blue: 0.42).opacity(0.38), lineWidth: 0.9 * markScale * gs)
                .frame(width: 25 * markScale * gs, height: 34 * markScale * gs)
            DiamondShape()
                .fill(Color(red: 1.0, green: 0.80, blue: 0.34).opacity(0.28))
                .frame(width: 13 * markScale * gs, height: 18 * markScale * gs)
            Text("SH")
                .font(.system(size: 10 * markScale * gs, weight: .black, design: .serif))
                .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.48).opacity(0.58))
        }
    }

    // MARK: - Dynamic Styles

    private static let goldSelection = Color(red: 0.90, green: 0.72, blue: 0.20)

    private var borderColor: Color {
        if selected { return Self.goldSelection }
        if highlight { return Self.goldSelection.opacity(0.7) }
        return .clear
    }

    private var borderWidth: CGFloat {
        if selected { return 2.5 * gs }
        if highlight { return 1.5 * gs }
        return 0
    }

    private var shadowColor: Color {
        if selected { return Self.goldSelection.opacity(0.5) }
        if highlight { return Self.goldSelection.opacity(0.3) }
        if style == .opponent { return .black.opacity(0.55) }
        return .black.opacity(0.32)
    }

    private var shadowRadius: CGFloat {
        if selected { return 9 * gs }
        if highlight { return 5 * gs }
        if style == .opponent { return 3 * gs }
        return (small ? 2 : 4) * gs
    }

    private var shadowY: CGFloat {
        if selected { return 6 * gs }
        if style == .opponent { return 1.5 * gs }
        return (small ? 2 : 4) * gs
    }
}

enum CardViewStyle {
    case standard
    case opponent

    func width(small: Bool) -> CGFloat {
        switch self {
        case .standard: return small ? 38 : 58
        case .opponent: return 30
        }
    }

    func height(small: Bool) -> CGFloat {
        switch self {
        case .standard: return small ? 54 : 82
        case .opponent: return 40
        }
    }

    func cornerRadius(small: Bool) -> CGFloat {
        switch self {
        case .standard: return small ? 5 : 7
        case .opponent: return 4
        }
    }
}

// MARK: - Table

struct FeltTableBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.08)

            RadialGradient(
                colors: [
                    Color(red: 0.28, green: 0.18, blue: 0.08).opacity(0.5),
                    Color(red: 0.12, green: 0.08, blue: 0.04).opacity(0.3),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 350
            )

            Canvas { context, size in
                for index in 0..<60 {
                    let xSeed = CGFloat((index * 47 + 13) % 100) / 100
                    let ySeed = CGFloat((index * 71 + 29) % 100) / 100
                    let sizeSeed = CGFloat((index * 31) % 40 + 10) / 50
                    let opacity = Double((index * 19) % 30 + 5) / 1000
                    let rect = CGRect(
                        x: xSeed * size.width - sizeSeed * 20,
                        y: ySeed * size.height - sizeSeed * 20,
                        width: sizeSeed * 40,
                        height: sizeSeed * 40
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color.white.opacity(opacity))
                    )
                }
            }
            .blendMode(.overlay)

            Canvas { context, size in
                let noiseColor = Color.white.opacity(0.012)
                for index in 0..<200 {
                    let x = CGFloat((index * 73 + 17) % Int(size.width))
                    let y = CGFloat((index * 97 + 41) % Int(max(size.height, 1)))
                    let w: CGFloat = CGFloat((index * 13) % 3 + 1) * 0.5
                    context.fill(
                        Path(CGRect(x: x, y: y, width: w, height: w)),
                        with: .color(noiseColor)
                    )
                }
            }

            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        center: .center,
                        startRadius: 140,
                        endRadius: 500
                    )
                )
        }
    }
}

struct PileLandingZone: View {
    let recentPile: [Card]
    let pileCount: Int

    @Environment(\.gameScale) private var gs

    private func rotation(for index: Int, total: Int) -> Double {
        let seed = index + total
        let angles: [Double] = [-4, 2.5, -1.5, 3, -3.5, 1, -2, 4.5]
        return angles[seed % angles.count]
    }

    private func offset(for index: Int, total: Int) -> CGSize {
        let seed = index + total
        let offsets: [CGSize] = [
            CGSize(width: -1.5, height: -1),
            CGSize(width: 1, height: 0.5),
            CGSize(width: -0.5, height: 1),
            CGSize(width: 1.5, height: -0.5),
        ]
        return offsets[seed % offsets.count]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14 * gs)
                .fill(Color.black.opacity(0.12))
                .frame(width: 82 * gs, height: 108 * gs)
                .overlay(
                    RoundedRectangle(cornerRadius: 14 * gs)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.65, blue: 0.15).opacity(0.7),
                                    Color(red: 0.90, green: 0.45, blue: 0.10).opacity(0.5),
                                    Color(red: 0.95, green: 0.60, blue: 0.12).opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5 * gs
                        )
                )
                .shadow(color: Color(red: 0.95, green: 0.55, blue: 0.10).opacity(0.35), radius: 12 * gs)
                .shadow(color: Color(red: 0.90, green: 0.45, blue: 0.08).opacity(0.20), radius: 24 * gs)
                .shadow(color: .black.opacity(0.22), radius: 10 * gs, y: 5 * gs)
                .reportPileFrame()

            let visible = recentPile.suffix(4)
            ForEach(Array(visible.enumerated()), id: \.element.uid) { index, card in
                let isTop = index == visible.count - 1
                CardView(card: card, faceUp: true)
                    .hideIfInFlight(card.uid)
                    .rotationEffect(.degrees(rotation(for: index, total: pileCount)))
                    .offset(
                        x: offset(for: index, total: pileCount).width * gs,
                        y: offset(for: index, total: pileCount).height * gs
                    )
                    .zIndex(Double(index))
                    .allowsHitTesting(false)
                    .opacity(isTop ? 1 : 0.85)
            }
        }
    }
}

// MARK: - Card Details

private struct OrnamentalJokerMark: View {
    let scale: CGFloat
    let color: Color

    private var gold: Color {
        Color(red: 0.86, green: 0.62, blue: 0.18)
    }

    var body: some View {
        VStack(spacing: 3 * scale) {
            Text("JOKER")
                .font(.system(size: 8.5 * scale, weight: .black, design: .serif))
                .tracking(1.1 * scale)
                .foregroundStyle(gold.opacity(0.9))

            ZStack {
                DiamondShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                gold.opacity(0.20),
                                Color.white.opacity(0.12),
                                color.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 25 * scale, height: 31 * scale)

                DiamondShape()
                    .stroke(gold.opacity(0.55), lineWidth: 0.9 * scale)
                    .frame(width: 25 * scale, height: 31 * scale)

                DiamondShape()
                    .stroke(color.opacity(0.18), lineWidth: 0.45 * scale)
                    .frame(width: 18 * scale, height: 23 * scale)

                VStack(spacing: 1 * scale) {
                    Text("\u{2726}")
                        .font(.system(size: 9 * scale, weight: .semibold))
                    Text("J")
                        .font(.system(size: 16 * scale, weight: .black, design: .serif))
                    Text("\u{2726}")
                        .font(.system(size: 6.5 * scale, weight: .semibold))
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            color.opacity(0.94),
                            gold.opacity(0.78)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .white.opacity(0.45), radius: 0.45, y: 0.5)
            }

            HStack(spacing: 3 * scale) {
                Rectangle()
                    .fill(gold.opacity(0.45))
                    .frame(width: 9 * scale, height: 0.7 * scale)
                DiamondShape()
                    .fill(gold.opacity(0.65))
                    .frame(width: 4 * scale, height: 4 * scale)
                Rectangle()
                    .fill(gold.opacity(0.45))
                    .frame(width: 9 * scale, height: 0.7 * scale)
            }
        }
        .frame(width: 42 * scale, height: 46 * scale)
    }
}

private struct SuitPip: View {
    let suit: Suit
    let color: Color
    let size: CGFloat

    var body: some View {
        Text(suit.character)
            .font(.system(size: size, weight: .black, design: .serif))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        color.opacity(0.98),
                        color.opacity(0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .white.opacity(0.42), radius: 0.4, x: 0, y: 0.5)
            .shadow(color: color.opacity(0.18), radius: 0.8, x: 0, y: 0.4)
    }
}

private struct RoyalCardCenter: View {
    let card: Card
    let suitColor: Color
    let scale: CGFloat

    private var accentGold: Color {
        Color(red: 0.88, green: 0.62, blue: 0.16)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6 * scale)
                .fill(
                    LinearGradient(
                        colors: [
                            suitColor.opacity(0.09),
                            Color.white.opacity(0.16),
                            accentGold.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6 * scale)
                        .stroke(accentGold.opacity(0.34), lineWidth: 0.8 * scale)
                )
                .frame(width: 33 * scale, height: 43 * scale)

            VStack(spacing: 1 * scale) {
                Text(card.rank.label)
                    .font(.system(size: 23 * scale, weight: .black, design: .serif))
                    .foregroundStyle(suitColor)
                    .shadow(color: .white.opacity(0.55), radius: 0.6, y: 0.5)

                SuitPip(suit: card.suit, color: suitColor, size: 15 * scale)
            }
        }
        .rotationEffect(.degrees(card.rank == .queen ? -1.5 : 1.5))
    }
}

// MARK: - Diamond Shape

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
        }
    }
}

// MARK: - Previews

#Preview("Cards") {
    ZStack {
        Color.green.opacity(0.3).ignoresSafeArea()
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                CardView(card: Card(suit: .hearts, rank: .ace), faceUp: true)
                CardView(card: Card(suit: .spades, rank: .king), faceUp: true, highlight: true)
                CardView(card: Card(suit: .diamonds, rank: .queen), faceUp: true, selected: true)
                CardView(card: Card(suit: .clubs, rank: .ten), faceUp: false)
            }
            HStack(spacing: 8) {
                CardView(card: Card(suit: .hearts, rank: .two), faceUp: true, small: true)
                CardView(card: Card(suit: .spades, rank: .jack), faceUp: true, small: true)
                CardView(card: Card(suit: .clubs, rank: .seven), faceUp: false, small: true)
            }
        }
    }
}
