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

    static let snappySpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let quickSpring = Animation.spring(response: 0.25, dampingFraction: 0.7)
}

struct SelectionChip<Label: View>: View {
    let isSelected: Bool
    let width: CGFloat
    let height: CGFloat
    let selectedScale: CGFloat
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var shimmerPhase: CGFloat = -1

    private static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.76, green: 0.60, blue: 0.20),
                Color(red: 0.90, green: 0.75, blue: 0.30),
                Color(red: 0.76, green: 0.60, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button {
            withAnimation(GameTheme.snappySpring) {
                action()
            }
        } label: {
            label()
                .shadow(color: .black.opacity(isSelected ? 0.4 : 0.7), radius: 2, y: 1)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? AnyShapeStyle(Self.goldGradient) : AnyShapeStyle(GameTheme.inactiveChipFill))
                        .overlay(
                            shimmerOverlay(cornerRadius: 10)
                                .opacity(isSelected ? 1 : 0)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(isSelected ? 0 : 0.3), lineWidth: 1.5)
                        )
                        .shadow(color: isSelected ? Color.orange.opacity(0.4) : .clear, radius: 8, y: 2)
                )
                .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                .scaleEffect(isSelected ? selectedScale : 1.0)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }

    private func shimmerOverlay(cornerRadius: CGFloat) -> some View {
        GeometryReader { geo in
            let shimmerWidth = geo.size.width * 0.5
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: .white.opacity(0.25), location: 0.5),
                    .init(color: .white.opacity(0), location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: shimmerWidth)
            .offset(x: shimmerPhase * (geo.size.width + shimmerWidth) - shimmerWidth)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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

    @State private var shimmerPhase: CGFloat = -1

    private static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.76, green: 0.60, blue: 0.20),
                Color(red: 0.90, green: 0.75, blue: 0.30),
                Color(red: 0.76, green: 0.60, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

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
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Self.goldGradient)
                        .overlay(
                            shimmerOverlay
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        )
                        .shadow(color: Color.orange.opacity(0.4), radius: shadowRadius, y: shadowY)
                )
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { geo in
            let shimmerWidth = geo.size.width * 0.5
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: .white.opacity(0.25), location: 0.5),
                    .init(color: .white.opacity(0), location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: shimmerWidth)
            .offset(x: shimmerPhase * (geo.size.width + shimmerWidth) - shimmerWidth)
        }
    }
}

struct GoldShimmerText: View {
    let text: String
    let font: Font

    @State private var shimmerPhase: CGFloat = -1

    private var goldGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.85, green: 0.65, blue: 0.20),
                Color(red: 1.0, green: 0.85, blue: 0.35),
                Color(red: 0.85, green: 0.65, blue: 0.20)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(goldGradient)
            .shadow(color: Color.orange.opacity(0.3), radius: 4, y: 1)
            .overlay(shimmerOverlay.mask(Text(text).font(font)))
            .onAppear {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
    }

    private var shimmerOverlay: some View {
        GeometryReader { geo in
            let shimmerWidth = geo.size.width * 0.4
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: .white.opacity(0.5), location: 0.5),
                    .init(color: .white.opacity(0), location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: shimmerWidth)
            .offset(x: shimmerPhase * (geo.size.width + shimmerWidth) - shimmerWidth)
        }
    }
}

enum SwapSelection: Equatable {
    case hand(Int)
    case faceUp(Int)
}
