import SwiftUI

struct CardView: View {
    let card: Card
    let faceUp: Bool
    var highlight: Bool = false
    var selected: Bool = false
    var small: Bool = false
    var dimmed: Bool = false

    @Environment(\.gameScale) private var gs

    private var width: CGFloat { (small ? 38 : 58) * gs }
    private var height: CGFloat { (small ? 54 : 82) * gs }
    private var cornerRadius: CGFloat { (small ? 5 : 7) * gs }

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
        .opacity(dimmed ? 0.5 : 1)
        .offset(y: selected ? -14 * gs : 0)
        .scaleEffect(selected ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: selected)
    }

    // MARK: - Card Face

    private var cardFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.92),
                            Color(red: 0.96, green: 0.93, blue: 0.86)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            cardPaperTexture

            RoundedRectangle(cornerRadius: cornerRadius - 1)
                .stroke(Color.black.opacity(0.08), lineWidth: (small ? 0.5 : 0.7) * gs)
                .padding((small ? 2 : 3) * gs)

            if small {
                smallFaceContent
            } else {
                fullFaceContent
            }
        }
    }

    private var suitColor: Color {
        card.suit == .hearts || card.suit == .diamonds
            ? Color(red: 0.72, green: 0.04, blue: 0.05)
            : Color(red: 0.06, green: 0.06, blue: 0.08)
    }

    private var smallFaceContent: some View {
        VStack(spacing: 0) {
            Text(card.rank.label)
                .font(.system(size: 11 * gs, weight: .bold, design: .serif))
            Text(card.suit.character)
                .font(.system(size: 9 * gs))
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
            for index in 0..<18 {
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

    private var cornerMark: some View {
        VStack(spacing: -2 * gs) {
            Text(card.rank.label)
                .font(.system(size: 13 * gs, weight: .heavy, design: .serif))
            Text(card.suit.character)
                .font(.system(size: 10 * gs, weight: .bold))
        }
        .foregroundStyle(suitColor)
        .shadow(color: .white.opacity(0.45), radius: 0.5, y: 0.5)
    }

    @ViewBuilder
    private var centerPips: some View {
        if card.rank.rawValue <= Rank.ten.rawValue {
            pipLayout
        } else {
            VStack(spacing: 2 * gs) {
                Text(card.rank.label)
                    .font(.system(size: 24 * gs, weight: .black, design: .serif))
                Text(card.suit.character)
                    .font(.system(size: 20 * gs, weight: .bold))
            }
            .foregroundStyle(suitColor)
        }
    }

    private var pipLayout: some View {
        VStack(spacing: 4 * gs) {
            ForEach(pipRows.indices, id: \.self) { rowIndex in
                HStack(spacing: 8 * gs) {
                    ForEach(0..<pipRows[rowIndex], id: \.self) { _ in
                        Text(card.suit.character)
                            .font(.system(size: pipFontSize * gs, weight: .bold))
                            .foregroundStyle(suitColor.opacity(0.9))
                    }

                }
                .rotationEffect(rowIndex > pipRows.count / 2 ? .degrees(180) : .zero)
            }
        }
    }

    private var pipRows: [Int] {
        switch card.rank {
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
                            Color(red: 0.55, green: 0.42, blue: 0.18),
                            Color(red: 0.40, green: 0.30, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius - 1)
                .stroke(Color(red: 0.78, green: 0.66, blue: 0.34).opacity(0.4), lineWidth: (small ? 0.7 : 1) * gs)
                .padding(3 * gs)

            Canvas { context, size in
                let step: CGFloat = small ? 6 : 8
                let color = Color(red: 0.78, green: 0.66, blue: 0.34).opacity(0.12)
                for x in stride(from: -size.height, through: size.width + size.height, by: step) {
                    var downStroke = Path()
                    downStroke.move(to: CGPoint(x: x, y: 0))
                    downStroke.addLine(to: CGPoint(x: x - size.height, y: size.height))
                    context.stroke(downStroke, with: .color(color), lineWidth: 0.45)

                    var upStroke = Path()
                    upStroke.move(to: CGPoint(x: x, y: 0))
                    upStroke.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    context.stroke(upStroke, with: .color(color), lineWidth: 0.45)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 2))
            .padding(5 * gs)

            if !small {
                ZStack {
                    DiamondShape()
                        .fill(Color(red: 0.78, green: 0.66, blue: 0.34).opacity(0.15))
                        .frame(width: 25 * gs, height: 34 * gs)
                    DiamondShape()
                        .stroke(Color(red: 0.78, green: 0.66, blue: 0.34).opacity(0.30), lineWidth: 0.9)
                        .frame(width: 25 * gs, height: 34 * gs)
                    DiamondShape()
                        .fill(Color(red: 0.85, green: 0.72, blue: 0.38).opacity(0.25))
                        .frame(width: 13 * gs, height: 18 * gs)
                    Text("$")
                        .font(.system(size: 13 * gs, weight: .black, design: .serif))
                        .foregroundStyle(Color(red: 0.95, green: 0.85, blue: 0.55).opacity(0.4))
                }
            }

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

    // MARK: - Dynamic Styles

    private var borderColor: Color {
        if selected { return .green }
        if highlight { return Color.yellow }
        return .clear
    }

    private var borderWidth: CGFloat {
        if selected { return 2.5 * gs }
        if highlight { return 1.5 * gs }
        return 0
    }

    private var shadowColor: Color {
        if selected { return .green.opacity(0.45) }
        if highlight { return .yellow.opacity(0.3) }
        return .black.opacity(0.32)
    }

    private var shadowRadius: CGFloat {
        if selected { return 9 * gs }
        if highlight { return 5 * gs }
        return (small ? 2 : 4) * gs
    }

    private var shadowY: CGFloat {
        if selected { return 6 * gs }
        return (small ? 2 : 4) * gs
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
    let topCard: Card?
    let pileCount: Int

    @Environment(\.gameScale) private var gs

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

            ForEach(0..<min(pileCount, 3), id: \.self) { index in
                RoundedRectangle(cornerRadius: 7 * gs)
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 58 * gs, height: 82 * gs)
                    .rotationEffect(.degrees(Double(index - 1) * 5))
                    .offset(x: CGFloat(index - 1) * 2 * gs, y: CGFloat(index) * 1.5 * gs)
            }

            Color.clear
                .frame(width: 58 * gs, height: 82 * gs)
                .reportPileFrame()

            if let topCard {
                CardView(card: topCard, faceUp: true)
                    .hideIfInFlight(topCard.uid)
                    .rotationEffect(.degrees(Double((pileCount % 5) - 2) * 2.5))
                    .transition(.opacity)
            }
        }
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
