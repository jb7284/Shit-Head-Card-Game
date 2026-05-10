import SwiftUI

let gameCoordinateSpace: String = "gameSpace"

struct CardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct PileFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

struct HandCenterPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct DrawPileFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    func reportCardFrame(_ id: UUID) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: CardFramePreferenceKey.self,
                    value: [id: geo.frame(in: .named(gameCoordinateSpace))]
                )
            }
        )
    }

    func reportPileFrame() -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: PileFramePreferenceKey.self,
                    value: geo.frame(in: .named(gameCoordinateSpace))
                )
            }
        )
    }

    func reportHandCenter(_ playerID: String) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: HandCenterPreferenceKey.self,
                    value: [playerID: geo.frame(in: .named(gameCoordinateSpace))]
                )
            }
        )
    }

    func reportDrawPileFrame(_ playerID: String) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DrawPileFramePreferenceKey.self,
                    value: [playerID: geo.frame(in: .named(gameCoordinateSpace))]
                )
            }
        )
    }
}

private struct InFlightCardIDsKey: EnvironmentKey {
    static let defaultValue: Set<UUID> = []
}

extension EnvironmentValues {
    var inFlightCardIDs: Set<UUID> {
        get { self[InFlightCardIDsKey.self] }
        set { self[InFlightCardIDsKey.self] = newValue }
    }
}

extension View {
    func hideIfInFlight(_ id: UUID) -> some View {
        modifier(HideIfInFlightModifier(id: id))
    }
}

private struct HideIfInFlightModifier: ViewModifier {
    let id: UUID
    @Environment(\.inFlightCardIDs) private var inFlightIDs

    func body(content: Content) -> some View {
        content.opacity(inFlightIDs.contains(id) ? 0 : 1)
    }
}

struct CardFlight: Identifiable {
    let id: UUID
    let card: Card
    let from: CGRect
    let to: CGRect
    let startsFaceUp: Bool
    let endsFaceUp: Bool
    let startDelay: TimeInterval
    let duration: TimeInterval
}

struct FlyingCardView: View {
    let flight: CardFlight
    let onComplete: (UUID) -> Void

    @Environment(\.gameScale) private var gs
    @State private var progress: CGFloat = 0
    @State private var hasStarted: Bool = false

    private var shouldFlip: Bool { flight.startsFaceUp != flight.endsFaceUp }
    private var renderWidth: CGFloat { 58 * gs }
    private var renderHeight: CGFloat { 82 * gs }

    var body: some View {
        let p = progress
        let rotation: Double = shouldFlip ? Double(p) * 180 : 0

        let x = flight.from.midX + (flight.to.midX - flight.from.midX) * p
        let baseY = flight.from.midY + (flight.to.midY - flight.from.midY) * p
        let arcLift = -55 * sin(Double(p) * .pi)
        let y = baseY + CGFloat(arcLift)

        let sourceScaleX = max(flight.from.width, 1) / renderWidth
        let sourceScaleY = max(flight.from.height, 1) / renderHeight
        let destScaleX = max(flight.to.width, 1) / renderWidth
        let destScaleY = max(flight.to.height, 1) / renderHeight
        let scaleX = sourceScaleX + (destScaleX - sourceScaleX) * p
        let scaleY = sourceScaleY + (destScaleY - sourceScaleY) * p

        return Group {
            if shouldFlip {
                ZStack {
                    CardView(card: flight.card, faceUp: flight.startsFaceUp)
                        .opacity(rotation < 90 ? 1 : 0)
                    CardView(card: flight.card, faceUp: flight.endsFaceUp)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        .opacity(rotation >= 90 ? 1 : 0)
                }
                .scaleEffect(x: scaleX, y: scaleY)
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
            } else {
                CardView(card: flight.card, faceUp: flight.endsFaceUp)
                    .scaleEffect(x: scaleX, y: scaleY)
            }
        }
        .position(x: x, y: y)
        .allowsHitTesting(false)
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            let totalSeconds = flight.startDelay + flight.duration
            DispatchQueue.main.asyncAfter(deadline: .now() + flight.startDelay) {
                withAnimation(.easeInOut(duration: flight.duration)) {
                    progress = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + totalSeconds + 0.02) {
                onComplete(flight.id)
            }
        }
    }
}
