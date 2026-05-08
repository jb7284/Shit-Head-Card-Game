import SwiftUI

struct CardView: View {
    let card: Card
    let faceUp: Bool
    var highlight: Bool = false
    var selected: Bool = false
    var small: Bool = false
    var dimmed: Bool = false

    private var width: CGFloat { small ? 38 : 58 }
    private var height: CGFloat { small ? 54 : 82 }
    private var cornerRadius: CGFloat { small ? 5 : 7 }

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
        .offset(y: selected ? -14 : 0)
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
                .stroke(Color.black.opacity(0.08), lineWidth: small ? 0.5 : 0.7)
                .padding(small ? 2 : 3)

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
                .font(.system(size: 11, weight: .bold, design: .serif))
            Text(suitCharacter)
                .font(.system(size: 9))
        }
        .foregroundStyle(suitColor)
    }

    private var fullFaceContent: some View {
        ZStack {
            cornerMark
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 5)
            .padding(.top, 4)

            cornerMark
            .rotationEffect(.degrees(180))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 5)
            .padding(.bottom, 4)

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
        VStack(spacing: -2) {
            Text(card.rank.label)
                .font(.system(size: 13, weight: .heavy, design: .serif))
            Text(suitCharacter)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(suitColor)
        .shadow(color: .white.opacity(0.45), radius: 0.5, y: 0.5)
    }

    @ViewBuilder
    private var centerPips: some View {
        if card.rank.rawValue <= Rank.ten.rawValue {
            pipLayout
        } else {
            VStack(spacing: 2) {
                Text(card.rank.label)
                    .font(.system(size: 24, weight: .black, design: .serif))
                Text(suitCharacter)
                    .font(.system(size: 20, weight: .bold))
            }
            .foregroundStyle(suitColor)
        }
    }

    private var pipLayout: some View {
        VStack(spacing: 4) {
            ForEach(pipRows.indices, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(0..<pipRows[rowIndex], id: \.self) { _ in
                        Text(suitCharacter)
                            .font(.system(size: pipFontSize, weight: .bold))
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

    private var suitCharacter: String {
        switch card.suit {
        case .hearts: return "\u{2665}"
        case .diamonds: return "\u{2666}"
        case .clubs: return "\u{2663}"
        case .spades: return "\u{2660}"
        }
    }

    // MARK: - Card Back

    private var cardBack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.12, blue: 0.30),
                            Color(red: 0.16, green: 0.22, blue: 0.48)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius - 1)
                .stroke(Color.white.opacity(0.28), lineWidth: small ? 0.7 : 1)
                .padding(3)

            Canvas { context, size in
                let step: CGFloat = small ? 6 : 8
                let color = Color.white.opacity(0.08)
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
            .padding(5)

            if !small {
                ZStack {
                    DiamondShape()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 25, height: 34)
                    DiamondShape()
                        .stroke(Color.white.opacity(0.22), lineWidth: 0.9)
                        .frame(width: 25, height: 34)
                    DiamondShape()
                        .fill(Color(red: 0.78, green: 0.66, blue: 0.34).opacity(0.22))
                        .frame(width: 13, height: 18)
                    Text("$")
                        .font(.system(size: 13, weight: .black, design: .serif))
                        .foregroundStyle(.white.opacity(0.28))
                }
            }

            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.black.opacity(0.18)],
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
        if selected { return 2.5 }
        if highlight { return 1.5 }
        return 0
    }

    private var shadowColor: Color {
        if selected { return .green.opacity(0.45) }
        if highlight { return .yellow.opacity(0.3) }
        return .black.opacity(0.32)
    }

    private var shadowRadius: CGFloat {
        if selected { return 9 }
        if highlight { return 5 }
        return small ? 2 : 4
    }

    private var shadowY: CGFloat {
        if selected { return 6 }
        return small ? 2 : 4
    }
}

// MARK: - Table

struct FeltTableBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.18, blue: 0.09),
                    Color(red: 0.08, green: 0.36, blue: 0.18),
                    Color(red: 0.03, green: 0.16, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.18, green: 0.48, blue: 0.24).opacity(0.85),
                    Color(red: 0.02, green: 0.10, blue: 0.06).opacity(0.9)
                ],
                center: .center,
                startRadius: 40,
                endRadius: 560
            )

            Canvas { context, size in
                let threadColor = Color.white.opacity(0.025)
                for y in stride(from: 0, through: size.height, by: 5) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y + sin(y * 0.03) * 1.5))
                    context.stroke(path, with: .color(threadColor), lineWidth: 0.5)
                }
                for x in stride(from: 0, through: size.width, by: 7) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + cos(x * 0.04) * 1.2, y: size.height))
                    context.stroke(path, with: .color(Color.black.opacity(0.025)), lineWidth: 0.5)
                }
            }
            .blendMode(.overlay)

            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.35)],
                        center: .center,
                        startRadius: 180,
                        endRadius: 620
                    )
                )
        }
    }
}

struct PileLandingZone: View {
    let topCard: Card?
    let pileCount: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.12))
                .frame(width: 82, height: 108)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 10, y: 5)

            ForEach(0..<min(pileCount, 3), id: \.self) { index in
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 58, height: 82)
                    .rotationEffect(.degrees(Double(index - 1) * 5))
                    .offset(x: CGFloat(index - 1) * 2, y: CGFloat(index) * 1.5)
            }

            if let topCard {
                CardView(card: topCard, faceUp: true)
                    .rotationEffect(.degrees(Double((pileCount % 5) - 2) * 2.5))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .scale(scale: 1.2).combined(with: .opacity)
                    ))
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
