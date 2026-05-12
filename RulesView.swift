import SwiftUI

struct RulesSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.1)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("How to Play")
                            .font(.title2.bold())
                        Spacer()
                        Button("Done") { isPresented = false }
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Text("Play cards equal to or higher than the top of the pile. If you can't play, pick up the pile. First to empty all cards wins — last player left is stuck with the stack.")
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Special Cards")
                            .font(.headline)
                        ruleRow(rank: "2", name: "Wild", detail: "Can be played on anything")
                        ruleRow(rank: "7", name: "Under", detail: "Next player must play 7 or lower")
                        ruleRow(rank: "8", name: "Skip", detail: "Skips the next player's turn")
                        ruleRow(rank: "9", name: "Reverse", detail: "Reverses the direction of play")
                        ruleRow(rank: "10", name: "Burn", detail: "Clears the entire pile")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Four of a Kind")
                            .font(.headline)
                        Text("If the top 4 cards on the pile share the same rank, the pile is burned automatically.")
                            .font(.subheadline)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Zones")
                            .font(.headline)
                        Text("Each player has:")
                            .font(.subheadline)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• **Draw pile** — drawn to keep 3 in hand")
                            Text("• **Hand** — played first (3 card minimum)")
                            Text("• **Face-up** — played after hand is empty")
                            Text("• **Face-down** — blind flips, played last")
                        }
                        .font(.subheadline)
                    }
                }
                .padding(24)
            }
            .foregroundStyle(.white)
        }
    }

    private func ruleRow(rank: String, name: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Text(rank)
                .font(.system(size: 18, weight: .black, design: .serif))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}
