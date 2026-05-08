import SwiftUI

struct StartScreenView: View {
    @Binding var playerCount: Int
    @Binding var difficulty: Difficulty

    let onDeal: () -> Void
    let onShowRules: () -> Void

    var body: some View {
        ZStack {
            Text("\u{1F4A9}")
                .font(.system(size: 150))
                .opacity(0.5)
                .offset(y: -80)

            VStack(spacing: 0) {
                Spacer()
                title
                Spacer()
                setupControls
                Spacer().frame(height: 24)
                dealButton
                Spacer().frame(height: 16)
                rulesButton
                Spacer().frame(height: 20)
            }
        }
    }

    private var title: some View {
        Text("$H!T HEAD")
            .font(.system(size: 36, weight: .black, design: .serif))
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, .white.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
    }

    private var setupControls: some View {
        VStack(spacing: 20) {
            playerCountPicker
            difficultyPicker
        }
    }

    private var playerCountPicker: some View {
        VStack(spacing: 10) {
            pickerTitle("Players")

            HStack(spacing: 8) {
                ForEach(2...6, id: \.self) { count in
                    SelectionChip(
                        isSelected: playerCount == count,
                        width: 42,
                        height: 42,
                        selectedScale: 1.08
                    ) {
                        playerCount = count
                    } label: {
                        Text("\(count)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                }
            }
        }
    }

    private var difficultyPicker: some View {
        VStack(spacing: 10) {
            pickerTitle("Difficulty")

            HStack(spacing: 8) {
                ForEach(Difficulty.allCases, id: \.self) { level in
                    SelectionChip(
                        isSelected: difficulty == level,
                        width: 72,
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
            width: 160,
            height: 50,
            cornerRadius: 14,
            action: onDeal
        ) {
            Text("Deal")
                .font(.system(size: 18, weight: .bold))
        }
    }

    private var rulesButton: some View {
        Button(action: onShowRules) {
            Text("Rules")
                .font(.system(size: 14, weight: .medium))
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
