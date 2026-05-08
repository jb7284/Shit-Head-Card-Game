import SwiftUI

struct CardView: View {
    let card: Card
    let faceUp: Bool
    var highlight: Bool = false
    var selected: Bool = false
    var small: Bool = false
    var dimmed: Bool = false

    private var width: CGFloat { small ? 36 : 56 }
    private var height: CGFloat { small ? 50 : 78 }

    var body: some View {
        ZStack {
            if faceUp {
                cardFace
            } else {
                cardBack
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: small ? 4 : 6))
        .overlay(
            RoundedRectangle(cornerRadius: small ? 4 : 6)
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
            RoundedRectangle(cornerRadius: small ? 4 : 6)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.99), Color(white: 0.93)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Subtle texture
            RoundedRectangle(cornerRadius: small ? 4 : 6)
                .fill(.white.opacity(0.4))
                .blendMode(.overlay)

            if small {
                smallFaceContent
            } else {
                fullFaceContent
            }
        }
    }

    private var suitColor: Color {
        card.suit == .hearts || card.suit == .diamonds
            ? Color(red: 0.8, green: 0.1, blue: 0.1)
            : Color(red: 0.1, green: 0.1, blue: 0.15)
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
            // Top-left corner
            VStack(spacing: -2) {
                Text(card.rank.label)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                Text(suitCharacter)
                    .font(.system(size: 10))
            }
            .foregroundStyle(suitColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 4)
            .padding(.top, 3)

            // Bottom-right corner (rotated)
            VStack(spacing: -2) {
                Text(card.rank.label)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                Text(suitCharacter)
                    .font(.system(size: 10))
            }
            .foregroundStyle(suitColor)
            .rotationEffect(.degrees(180))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 4)
            .padding(.bottom, 3)

            // Center suit
            Text(suitCharacter)
                .font(.system(size: 26))
                .foregroundStyle(suitColor.opacity(0.85))
        }
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
            RoundedRectangle(cornerRadius: small ? 4 : 6)
                .fill(Color(red: 0.12, green: 0.18, blue: 0.42))

            // Inner border
            RoundedRectangle(cornerRadius: small ? 3 : 5)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                .padding(3)

            // Diamond pattern
            Canvas { context, size in
                let step: CGFloat = small ? 7 : 10
                let color = Color.white.opacity(0.07)
                for x in stride(from: -size.height, through: size.width + size.height, by: step) {
                    var d1 = Path()
                    d1.move(to: CGPoint(x: x, y: 0))
                    d1.addLine(to: CGPoint(x: x - size.height, y: size.height))
                    context.stroke(d1, with: .color(color), lineWidth: 0.5)

                    var d2 = Path()
                    d2.move(to: CGPoint(x: x, y: 0))
                    d2.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    context.stroke(d2, with: .color(color), lineWidth: 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: small ? 3 : 5))
            .padding(3)

            // Center ornament
            if !small {
                ZStack {
                    DiamondShape()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 22, height: 30)
                    DiamondShape()
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                        .frame(width: 22, height: 30)
                    DiamondShape()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 12, height: 16)
                }
            }

            // Outer border
            RoundedRectangle(cornerRadius: small ? 4 : 6)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
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
        if selected { return .green.opacity(0.4) }
        if highlight { return .yellow.opacity(0.25) }
        return .black.opacity(0.2)
    }

    private var shadowRadius: CGFloat {
        if selected { return 8 }
        if highlight { return 4 }
        return 2
    }

    private var shadowY: CGFloat {
        if selected { return 6 }
        return 2
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
