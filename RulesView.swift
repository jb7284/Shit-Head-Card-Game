import SwiftUI

struct RulesSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.gameScale) private var gs

    private let specialCards: [(rank: Rank, title: String, detail: String)] = [
        (.two, "Wild", "Play a 2 on anything to reset the pile."),
        (.seven, "Under", "After a 7, the next play must be 7 or lower."),
        (.eight, "Skip", "Skips the next active player."),
        (.nine, "Reverse", "Changes the direction of play."),
        (.ten, "Burn", "Clears the pile and gives you another turn."),
        (.joker, "Joker", "Choose who has to take the pile.")
    ]

    var body: some View {
        ZStack {
            Image("playing_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.48).ignoresSafeArea())

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    objectiveCard
                    specialCardsSection
                    zonesSection
                    burnSection
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
                .frame(maxWidth: 720)
            }
        }
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rules")
                    .font(.system(size: 34, weight: .black, design: .serif))
                Text("Shed your hand, face-up cards, then face-down cards.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.12)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var objectiveCard: some View {
        rulesPanel {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    CardView(card: Card(suit: .spades, rank: .ace), faceUp: false, small: true)
                        .rotationEffect(.degrees(-10))
                    CardView(card: Card(suit: .hearts, rank: .king), faceUp: true, small: true)
                        .offset(x: 18, y: 8)
                        .rotationEffect(.degrees(9))
                }
                .frame(width: 74, height: 72)

                VStack(alignment: .leading, spacing: 6) {
                    Text("How You Win")
                        .font(.headline)
                    Text("Play equal to or higher than the pile. You may also pick up the pile voluntarily at any time. First out wins; the last player holding cards loses.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var specialCardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Special Cards")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], spacing: 10) {
                ForEach(specialCards, id: \.rank) { item in
                    rulesPanel {
                        HStack(spacing: 12) {
                            CardView(card: Card(suit: item.rank == .joker ? .clubs : .spades, rank: item.rank),
                                     faceUp: true,
                                     small: true,
                                     style: .opponent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.subheadline.bold())
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.66))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private var zonesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Card Zones")

            rulesPanel {
                VStack(spacing: 12) {
                    zoneRow(icon: "rectangle.stack.fill", title: "Draw Pile", detail: "Draw back up to 3 cards in hand.")
                    zoneRow(icon: "hand.raised.fill", title: "Hand", detail: "Play these first.")
                    zoneRow(icon: "rectangle.portrait.on.rectangle.portrait.fill", title: "Face Up", detail: "Available after your hand is empty.")
                    zoneRow(icon: "questionmark.square.fill", title: "Face Down", detail: "Blind flips are played last.")
                }
            }
        }
    }

    private var burnSection: some View {
        rulesPanel {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.orange)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.orange.opacity(0.16)))

                VStack(alignment: .leading, spacing: 5) {
                    Text("Four of a Kind Burns")
                        .font(.headline)
                    Text("If the top 4 cards on the pile share the same rank, the whole pile burns automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline.weight(.heavy))
            .foregroundStyle(.white.opacity(0.92))
    }

    private func zoneRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(red: 0.96, green: 0.76, blue: 0.32))
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.09)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }

            Spacer(minLength: 0)
        }
    }

    private func rulesPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.42))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(red: 0.96, green: 0.76, blue: 0.32).opacity(0.28), lineWidth: 1)
                    )
            )
    }
}
