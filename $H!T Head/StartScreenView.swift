import SwiftUI

struct StartScreenView: View {
    @Binding var difficulty: Difficulty

    let onDeal: () -> Void
    let onShowRules: () -> Void

    var body: some View {
        ZStack {
            decorativeCards
            decorativeChips

            VStack(spacing: 0) {
                Spacer()
                title
                Spacer()
                difficultyPicker
                Spacer().frame(height: 24)
                dealButton
                Spacer().frame(height: 16)
                rulesButton
                Spacer().frame(height: 20)
            }
        }
    }

    // MARK: - Decorative Elements

    private var decorativeCards: some View {
        GeometryReader { geo in
            let cardW: CGFloat = 50
            let cardH: CGFloat = 72

            Group {
                // Top-left cards
                DecoCardBack(width: cardW, height: cardH)
                    .rotationEffect(.degrees(-25))
                    .position(x: 38, y: 36)
                DecoCardBack(width: cardW, height: cardH)
                    .rotationEffect(.degrees(-8))
                    .position(x: 62, y: 30)

                // Top-right cards
                DecoCardBack(width: cardW, height: cardH)
                    .rotationEffect(.degrees(25))
                    .position(x: geo.size.width - 38, y: 36)
                DecoCardBack(width: cardW, height: cardH)
                    .rotationEffect(.degrees(8))
                    .position(x: geo.size.width - 62, y: 30)
            }
            .opacity(0.7)
        }
        .allowsHitTesting(false)
    }

    private var decorativeChips: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Group {
                PokerChipView(size: 28)
                    .position(x: 30, y: h * 0.45)
                PokerChipView(size: 22)
                    .position(x: 18, y: h * 0.58)
                    .opacity(0.6)

                PokerChipView(size: 28)
                    .position(x: w - 30, y: h * 0.45)
                PokerChipView(size: 22)
                    .position(x: w - 18, y: h * 0.58)
                    .opacity(0.6)

                PokerChipView(size: 20)
                    .position(x: 50, y: h - 28)
                    .opacity(0.5)
                PokerChipView(size: 20)
                    .position(x: w - 50, y: h - 28)
                    .opacity(0.5)

                PokerChipView(size: 16)
                    .position(x: w * 0.22, y: h * 0.18)
                    .opacity(0.4)
                PokerChipView(size: 16)
                    .position(x: w * 0.78, y: h * 0.18)
                    .opacity(0.4)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Title

    private var title: some View {
        Text("$H!T HEAD")
            .font(.system(size: 42, weight: .black, design: .serif))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.78, blue: 0.30),
                        Color(red: 0.85, green: 0.55, blue: 0.15),
                        Color(red: 0.95, green: 0.72, blue: 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: Color(red: 0.90, green: 0.60, blue: 0.10).opacity(0.5), radius: 8, y: 2)
            .shadow(color: .black.opacity(0.7), radius: 4, y: 3)
    }

    private var difficultyPicker: some View {
        VStack(spacing: 10) {
            pickerTitle("Difficulty")

            HStack(spacing: 8) {
                ForEach(Difficulty.allCases, id: \.self) { level in
                    SelectionChip(
                        isSelected: difficulty == level,
                        width: 80,
                        height: 36,
                        selectedScale: 1.05
                    ) {
                        difficulty = level
                    } label: {
                        Text(level.label)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                }
            }
        }
    }

    private var dealButton: some View {
        PrimaryGameButton(
            width: 180,
            height: 54,
            cornerRadius: 16,
            action: onDeal
        ) {
            Text("Deal")
                .font(.system(size: 22, weight: .bold))
        }
    }

    private var rulesButton: some View {
        Button(action: onShowRules) {
            HStack(spacing: 5) {
                Image(systemName: "book.closed")
                    .font(.system(size: 13, weight: .medium))
                Text("Rules")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.5))
        }
        .buttonStyle(.plain)
    }

    private func pickerTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .bold, design: .serif))
            .foregroundStyle(.white.opacity(0.7))
    }
}

// MARK: - Decorative Card Back

private struct DecoCardBack: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
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

            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(red: 0.78, green: 0.66, blue: 0.34).opacity(0.4), lineWidth: 0.7)
                .padding(2)

            RoundedRectangle(cornerRadius: 5)
                .stroke(
                    Color(red: 0.78, green: 0.66, blue: 0.34).opacity(0.3),
                    lineWidth: 0.5
                )
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
    }
}

// MARK: - Poker Chip

private struct PokerChipView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.70, green: 0.55, blue: 0.20),
                            Color(red: 0.45, green: 0.32, blue: 0.10)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )

            Circle()
                .stroke(Color(red: 0.85, green: 0.70, blue: 0.30).opacity(0.6), lineWidth: 1.5)

            Circle()
                .stroke(Color(red: 0.95, green: 0.80, blue: 0.40).opacity(0.3), lineWidth: 0.5)
                .padding(size * 0.18)

            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(Color(red: 0.95, green: 0.85, blue: 0.50).opacity(0.3))
                    .frame(width: size * 0.12, height: size * 0.06)
                    .offset(x: size * 0.38)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
    }
}
