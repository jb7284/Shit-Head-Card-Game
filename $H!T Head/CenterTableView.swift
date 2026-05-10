import SwiftUI

struct CenterTableView: View {
    let recentPile: [Card]
    let pileCount: Int
    private var topCard: Card? { recentPile.last }
    let showDropTarget: Bool
    let burnEffect: Bool
    let wildEffect: Bool
    let reverseEffect: Bool
    let reverseDirection: Int
    let canPickUpPile: Bool
    let mustPickUpPile: Bool
    let onPickUpPile: () -> Void

    @Environment(\.gameScale) private var gs

    private let pickUpButtonWidth: CGFloat = 110
    private let pickUpButtonHeight: CGFloat = 36
    private let pickUpButtonGap: CGFloat = 12

    var body: some View {
        pileArea
    }

    private var pileArea: some View {
        ZStack {
            HStack(spacing: pickUpButtonGap * gs) {
                Color.clear
                    .frame(width: pickUpButtonWidth * gs, height: pickUpButtonHeight * gs)

                VStack(spacing: 2) {
                    PileLandingZone(recentPile: recentPile, pileCount: pileCount)
                        .overlay(dropTargetOverlay)

                    Text("Pile: \(pileCount)")
                        .font(.system(size: 10 * gs))
                        .foregroundStyle(.white.opacity(0.4))
                }

                pickUpButton
                    .frame(width: pickUpButtonWidth * gs, height: pickUpButtonHeight * gs)
                    .opacity(canPickUpPile && !mustPickUpPile ? 1 : 0)
                    .allowsHitTesting(canPickUpPile && !mustPickUpPile)
                    .animation(.easeInOut(duration: 0.2), value: canPickUpPile)
                    .animation(.easeInOut(duration: 0.2), value: mustPickUpPile)
            }

            if reverseEffect {
                VStack(spacing: 2 * gs) {
                    Image(systemName: reverseDirection == -1
                          ? "arrow.counterclockwise"
                          : "arrow.clockwise")
                        .font(.system(size: 22 * gs, weight: .bold))
                    Text("REVERSE")
                        .font(.system(size: 11 * gs, weight: .black))
                }
                .foregroundStyle(Color(red: 0.85, green: 0.70, blue: 0.35))
                .shadow(color: .black.opacity(0.7), radius: 4, y: 2)
                .allowsHitTesting(false)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            if burnEffect {
                BurnOverlay(burnEffect: burnEffect)
            }

            if wildEffect {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 100 * gs, height: 100 * gs)
                    .transition(.opacity)
            }
        }
    }

    private var dropTargetOverlay: some View {
        RoundedRectangle(cornerRadius: 14 * gs)
            .stroke(Color.green, lineWidth: 2 * gs)
            .frame(width: 82 * gs, height: 108 * gs)
            .opacity(showDropTarget ? 0.6 : 0)
            .animation(.easeInOut(duration: 0.2), value: showDropTarget)
    }

    private var pickUpButton: some View {
        Button(action: onPickUpPile) {
            Text(mustPickUpPile ? "Pick Up" : "Voluntary Pick Up")
                .font(.system(size: 11 * gs, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8 * gs)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Capsule()
                        .fill(mustPickUpPile ? Color.red.opacity(0.75) : GameTheme.primaryButtonFill)
                        .shadow(
                            color: mustPickUpPile ? Color.red.opacity(0.35) : GameTheme.selectedShadow,
                            radius: 4 * gs,
                            y: 2 * gs
                        )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1 * gs)
                )
        }
        .buttonStyle(.plain)
    }
}

struct BurnOverlay: View {
    let burnEffect: Bool

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.orange.opacity(0.7))
                    .frame(width: 20, height: 30)
                    .offset(
                        x: cos(Double(index) * .pi / 4) * 70,
                        y: sin(Double(index) * .pi / 4) * 70
                    )
                    .rotationEffect(.degrees(Double(index) * 45 + 20))
                    .opacity(0)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.orange.opacity(0.6), .red.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(burnEffect ? 1.5 : 0.3)
                .opacity(burnEffect ? 0 : 1)
        }
        .transition(.opacity)
    }
}
