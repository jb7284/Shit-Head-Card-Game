import SwiftUI

struct GameOverOverlay: View {
    let loser: Player?
    let winner: String?
    let turnCount: Int
    var onPlayAgain: () -> Void

    @State private var showBackground = false
    @State private var showLoser = false
    @State private var loserExiting = false
    @State private var showWinner = false
    @State private var confettiActive = false
    @State private var showStats = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            Color.black
                .opacity(showBackground ? 0.85 : 0)
                .ignoresSafeArea()
                .animation(.easeIn(duration: 0.8), value: showBackground)

            loserSection

            VStack(spacing: 0) {
                Spacer()
                winnerSection

                Text("Game lasted \(turnCount) turns")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                    .opacity(showStats ? 1 : 0)
                    .animation(.easeIn(duration: 0.4), value: showStats)
                    .padding(.top, 12)

                Spacer()

                playAgainButton
                    .padding(.bottom, 20)
            }
            .opacity(showWinner ? 1 : 0)
            .animation(.easeIn(duration: 0.5), value: showWinner)
        }
        .onAppear { runSequence() }
    }

    // MARK: - Loser

    private var loserSection: some View {
        VStack(spacing: 10) {
            Text("\u{1F4A9}")
                .font(.system(size: 80))
                .scaleEffect(loserExiting ? 0.2 : (showLoser ? 1.0 : 3.0))
                .opacity(loserExiting ? 0 : (showLoser ? 1 : 0))

            Text(loser?.name ?? "Everyone")
                .font(.system(size: 42, weight: .black, design: .serif))
                .foregroundStyle(.white)
                .scaleEffect(loserExiting ? 0.4 : (showLoser ? 1.0 : 1.8))
                .opacity(loserExiting ? 0 : (showLoser ? 1 : 0))

            Text("is the $H!T HEAD!")
                .font(.system(size: 22, weight: .heavy, design: .serif))
                .foregroundStyle(.white.opacity(0.6))
                .scaleEffect(loserExiting ? 0.4 : (showLoser ? 1.0 : 1.5))
                .opacity(loserExiting ? 0 : (showLoser ? 1 : 0))
        }
        .offset(y: loserExiting ? -80 : 0)
        .animation(.easeInOut(duration: 1.2), value: showLoser)
        .animation(.easeInOut(duration: 1.0), value: loserExiting)
    }

    // MARK: - Winner

    @ViewBuilder
    private var winnerSection: some View {
        if let winner {
            VStack(spacing: 6) {
                ZStack {
                    if confettiActive {
                        ConfettiBurst()
                    }

                    Text("\u{1F451}")
                        .font(.system(size: 50))
                        .scaleEffect(showWinner ? 1.0 : 0.1)
                        .rotationEffect(.degrees(showWinner ? 0 : -30))
                        .animation(.spring(response: 0.6, dampingFraction: 0.45), value: showWinner)
                }

                Text(winner)
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.85, blue: 0.3),
                                Color(red: 1.0, green: 0.65, blue: 0.15)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.4), radius: 8, y: 2)
                    .offset(y: showWinner ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showWinner)

                Text("W I N N E R")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.yellow.opacity(0.5))
                    .tracking(4)
                    .opacity(showWinner ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.5), value: showWinner)
            }
        }
    }

    // MARK: - Button

    private var playAgainButton: some View {
        PrimaryGameButton(
            width: 160,
            height: 48,
            cornerRadius: 14,
            action: onPlayAgain
        ) {
            Text("Play Again")
                .font(.title3.bold())
        }
        .opacity(showButton ? 1 : 0)
        .offset(y: showButton ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showButton)
    }

    // MARK: - Timing

    private func runSequence() {
        withAnimation { showBackground = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showLoser = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            loserExiting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.8) {
            showWinner = true
            confettiActive = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            showStats = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
            showButton = true
        }
    }
}

// MARK: - Confetti

struct ConfettiBurst: View {
    @State private var fire = false

    private let pieces: [ConfettiPiece] = (0..<30).map { _ in
        ConfettiPiece()
    }

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                RoundedRectangle(cornerRadius: p.isCircle ? p.size : 1)
                    .fill(p.color)
                    .frame(width: p.size, height: p.isCircle ? p.size : p.size * 2)
                    .rotationEffect(.degrees(fire ? p.spin : 0))
                    .offset(
                        x: fire ? p.endX : 0,
                        y: fire ? p.endY : 0
                    )
                    .opacity(fire ? 0 : 0.9)
                    .animation(
                        .easeOut(duration: p.duration).delay(p.delay),
                        value: fire
                    )
            }
        }
        .onAppear { fire = true }
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let isCircle: Bool
    let endX: CGFloat
    let endY: CGFloat
    let spin: Double
    let duration: Double
    let delay: Double

    init() {
        let colors: [Color] = [
            .yellow, .orange, .red, .green,
            .blue, .purple, .pink, .mint
        ]
        color = colors[Int.random(in: 0..<colors.count)]
        size = CGFloat.random(in: 4...7)
        isCircle = Bool.random()
        let angle = Double.random(in: 0...(2.0 * .pi))
        let distance = CGFloat.random(in: 80...180)
        endX = cos(angle) * distance
        endY = sin(angle) * distance - 20
        spin = Double.random(in: 180...720) * (Bool.random() ? 1 : -1)
        duration = Double.random(in: 0.8...1.5)
        delay = Double.random(in: 0...0.3)
    }
}
