import SwiftUI

struct CenterTableView: View {
    let topCard: Card?
    let pileCount: Int
    let showDropTarget: Bool
    let burnEffect: Bool
    let wildEffect: Bool
    let mustPickUpPile: Bool
    let onPickUpPile: () -> Void

    @Environment(\.gameScale) private var gs

    var body: some View {
        VStack(spacing: 4 * gs) {
            pileArea
            actionButtons
        }
    }

    private var pileArea: some View {
        ZStack {
            VStack(spacing: 2) {
                PileLandingZone(topCard: topCard, pileCount: pileCount)
                    .overlay(dropTargetOverlay)

                Text("Pile: \(pileCount)")
                    .font(.system(size: 10 * gs))
                    .foregroundStyle(.white.opacity(0.4))
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

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if mustPickUpPile {
                Button(action: onPickUpPile) {
                    Text("Pick Up Pile")
                        .font(.system(size: 12 * gs, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14 * gs)
                        .padding(.vertical, 8 * gs)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.7))
                                .shadow(color: .red.opacity(0.3), radius: 4, y: 2)
                        )
                }
            }
        }
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
