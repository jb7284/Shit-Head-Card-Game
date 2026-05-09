import SwiftUI

struct CardShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * 4),
            y: 0
        ))
    }
}

private struct RejectionShakeIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

private struct RejectionShakeTriggerKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var rejectionShakeID: UUID? {
        get { self[RejectionShakeIDKey.self] }
        set { self[RejectionShakeIDKey.self] = newValue }
    }

    var rejectionShakeTrigger: CGFloat {
        get { self[RejectionShakeTriggerKey.self] }
        set { self[RejectionShakeTriggerKey.self] = newValue }
    }
}

extension View {
    func rejectionShake(_ cardID: UUID) -> some View {
        modifier(RejectionShakeModifier(cardID: cardID))
    }
}

private struct RejectionShakeModifier: ViewModifier {
    let cardID: UUID
    @Environment(\.rejectionShakeID) private var shakeID
    @Environment(\.rejectionShakeTrigger) private var shakeTrigger

    func body(content: Content) -> some View {
        content.modifier(
            CardShakeEffect(animatableData: cardID == shakeID ? shakeTrigger : 0)
        )
    }
}

struct RejectionTooltip: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color(red: 0.55, green: 0.15, blue: 0.10).opacity(0.92))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.7)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
            )
    }
}
