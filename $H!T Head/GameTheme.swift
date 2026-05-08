import SwiftUI

private struct GameScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var gameScale: CGFloat {
        get { self[GameScaleKey.self] }
        set { self[GameScaleKey.self] = newValue }
    }
}

enum GameTheme {
    static let primaryButtonFill = Color(red: 0.35, green: 0.22, blue: 0.13)
    static let selectedShadow = Color(red: 0.35, green: 0.22, blue: 0.13).opacity(0.5)
    static let inactiveChipFill = Color.white.opacity(0.15)
}

struct SelectionChip<Label: View>: View {
    let isSelected: Bool
    let width: CGFloat
    let height: CGFloat
    let selectedScale: CGFloat
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        } label: {
            label()
                .shadow(color: .black.opacity(isSelected ? 0 : 0.7), radius: 2, y: 1)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? GameTheme.primaryButtonFill : GameTheme.inactiveChipFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(isSelected ? 0 : 0.3), lineWidth: 1.5)
                        )
                        .shadow(color: isSelected ? GameTheme.selectedShadow : .clear, radius: 8, y: 2)
                )
                .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                .scaleEffect(isSelected ? selectedScale : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryGameButton<Label: View>: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowY: CGFloat
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    init(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat,
        shadowRadius: CGFloat = 8,
        shadowY: CGFloat = 3,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowY = shadowY
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .foregroundStyle(.white)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(GameTheme.primaryButtonFill)
                        .shadow(color: GameTheme.selectedShadow, radius: shadowRadius, y: shadowY)
                )
        }
        .buttonStyle(.plain)
    }
}

enum SwapSelection: Equatable {
    case hand(Int)
    case faceUp(Int)
}
