import SwiftUI

struct GameOverOverlay: View {
    let loser: Player?
    let winner: String?
    var onPlayAgain: () -> Void

    @State private var showBackground = false
    @State private var showLoser = false
    @State private var loserExiting = false
    @State private var showWinner = false
    @State private var confettiActive = false
    @State private var showButton = false
    @State private var burstText: String?
    @State private var burstScale: CGFloat = 0.35
    @State private var burstOpacity: CGFloat = 0

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

                Spacer()

                playAgainButton
                    .padding(.bottom, 20)
            }
            .opacity(showWinner ? 1 : 0)
            .animation(.easeIn(duration: 0.5), value: showWinner)

            outcomeBurstText
        }
        .onAppear { runSequence() }
    }

    // MARK: - Loser

    private var loserSection: some View {
        VStack(spacing: 16) {
            Image("loser_mascot")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 500, maxHeight: 500)
                .shadow(color: .black.opacity(0.65), radius: 28, y: 16)
            .scaleEffect(loserExiting ? 0.2 : (showLoser ? 1.0 : 3.0))
            .opacity(loserExiting ? 0 : (showLoser ? 1 : 0))

            Text(loser?.name ?? "Everyone")
                .font(.system(size: 44, weight: .black, design: .serif))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.8), radius: 8, y: 3)
                .scaleEffect(loserExiting ? 0.4 : (showLoser ? 1.0 : 1.8))
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
            VStack(spacing: 10) {
                ZStack {
                    if confettiActive {
                        ConfettiBurst()
                    }

                    ZStack(alignment: .top) {
                        Image("winner_mascot")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 540, maxHeight: 540)
                            .shadow(color: Color.orange.opacity(0.45), radius: 24, y: 10)
                    }
                    .winnerShimmer(active: showWinner)
                    .scaleEffect(showWinner ? 1.0 : 0.1)
                    .rotationEffect(.degrees(showWinner ? 0 : -30))
                    .animation(.spring(response: 0.6, dampingFraction: 0.45), value: showWinner)
                }

                GoldShimmerText(
                    text: winner,
                    font: .system(size: 44, weight: .black, design: .serif)
                )
                .offset(y: showWinner ? 0 : 30)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showWinner)
            }
        }
    }

    @ViewBuilder
    private var outcomeBurstText: some View {
        if let burstText {
            GeometryReader { proxy in
                Text(burstText)
                    .font(.system(size: min(proxy.size.width * 0.2, 190), weight: .black, design: .serif))
                    .foregroundStyle(.white)
                    .tracking(6)
                    .shadow(color: .black.opacity(0.9), radius: 18, y: 8)
                    .scaleEffect(burstScale)
                    .opacity(burstOpacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .allowsHitTesting(false)
            .zIndex(900)
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
            runOutcomeBurst("LOSER")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            loserExiting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.8) {
            showWinner = true
            confettiActive = true
            runOutcomeBurst("WINNER")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
            showButton = true
        }
    }

    private func runOutcomeBurst(_ text: String) {
        burstText = text
        burstScale = 0.35
        burstOpacity = 0

        withAnimation(.easeOut(duration: 0.18)) {
            burstOpacity = 1
            burstScale = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.52)) {
                burstScale = 2.15
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeIn(duration: 0.35)) {
                burstScale = 0.72
                burstOpacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if burstText == text {
                burstText = nil
            }
        }
    }
}

// MARK: - Fly Swarm

struct FlySwarm: View {
    private let flies: [FlyPath] = (0..<6).map { _ in FlyPath() }

    var body: some View {
        ZStack {
            ForEach(flies) { fly in
                FlyView(fly: fly)
            }
        }
    }
}

private struct FlyView: View {
    let fly: FlyPath
    @State private var phase: CGFloat = 0

    var body: some View {
        Text("\u{1FAB0}")
            .font(.system(size: fly.size))
            .opacity(0.85)
            .modifier(FlyMotion(fly: fly, phase: phase))
            .onAppear {
                withAnimation(
                    .linear(duration: fly.loopDuration)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

private struct FlyMotion: Animatable, ViewModifier {
    let fly: FlyPath
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        let angle = phase * .pi * 2 * fly.loops
        let radiusX = fly.radiusX + sin(angle * 1.7) * fly.wobble
        let radiusY = fly.radiusY + cos(angle * 1.3) * fly.wobble
        let x = cos(angle + fly.startAngle) * radiusX
        let y = sin(angle + fly.startAngle) * radiusY + fly.verticalDrift * phase

        content
            .offset(x: x, y: y)
            .scaleEffect(x: cos(angle) > 0 ? 1 : -1, y: 1)
    }
}

private struct FlyPath: Identifiable {
    let id = UUID()
    let size: CGFloat
    let radiusX: CGFloat
    let radiusY: CGFloat
    let wobble: CGFloat
    let startAngle: CGFloat
    let loops: CGFloat
    let loopDuration: Double
    let verticalDrift: CGFloat

    init() {
        size = CGFloat.random(in: 14...22)
        radiusX = CGFloat.random(in: 35...80)
        radiusY = CGFloat.random(in: 25...55)
        wobble = CGFloat.random(in: 5...15)
        startAngle = CGFloat.random(in: 0...(2 * .pi))
        loops = CGFloat.random(in: 2...4)
        loopDuration = Double.random(in: 2.0...3.5)
        verticalDrift = CGFloat.random(in: -15...15)
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

// MARK: - Joker Target Picker

struct JokerTargetPicker: View {
    let players: [Player]
    let jokerPlayerIndex: Int
    let pileCount: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("\u{1F0CF}")
                    .font(.system(size: 50))

                Text("Give pile to...")
                    .font(.system(size: 22, weight: .black, design: .serif))
                    .foregroundStyle(.white)

                if pileCount > 0 {
                    Text("\(pileCount) card\(pileCount == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }

                VStack(spacing: 12) {
                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        if index != jokerPlayerIndex && player.hasCards {
                            Button {
                                withAnimation(GameTheme.snappySpring) {
                                    onSelect(index)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(avatar: player.avatar, size: 36)
                                    Text(player.name)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    let total = player.hand.count + player.faceUp.count + player.faceDown.count + player.drawPile.count
                                    Text("\(total) cards")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Winner Shimmer Modifier

private struct WinnerShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let shimmerWidth = geo.size.width * 0.4
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0), location: 0),
                            .init(color: .white.opacity(0.4), location: 0.5),
                            .init(color: .white.opacity(0), location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: shimmerWidth)
                    .offset(x: phase * (geo.size.width + shimmerWidth) - shimmerWidth)
                }
                .blendMode(.sourceAtop)
                .opacity(active ? 1 : 0)
            )
            .compositingGroup()
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func winnerShimmer(active: Bool) -> some View {
        modifier(WinnerShimmerModifier(active: active))
    }
}
