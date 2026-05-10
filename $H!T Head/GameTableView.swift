import SwiftUI

struct GameTableView: View {
    let engine: GameEngine
    @Binding var selectedCards: [Card]
    @Binding var dragCardID: UUID?
    @Binding var dragOffset: CGSize

    let burnEffect: Bool
    let wildEffect: Bool
    let reverseEffect: Bool
    let reverseDirection: Int
    let turnPulse: Bool
    let skippedPlayerID: String?
    let revealedFaceDownIndex: Int?
    let pendingBurnPile: [Card]
    let onPickUpPile: () -> Void
    let onFaceDownTap: (Int) -> Void
    let onCardTap: (Card) -> Void
    let onCardDoubleTap: (Card) -> Void
    let onDragStart: (Card) -> Void
    let onDragUpdate: (CGSize) -> Void
    let onDragEnd: (CGSize) -> Void

    private var showHints: Bool { engine.difficulty == .easy }

    private var opponentLayout: OpponentLayout {
        OpponentLayout(players: engine.state.players)
    }

    var body: some View {
        VStack(spacing: 0) {
            topOpponent
                .padding(.bottom, 4)

            HStack(spacing: 0) {
                SideOpponentView(
                    player: opponentLayout.left,
                    active: isCurrentPlayer(opponentLayout.left),
                    isNext: isNextPlayer(opponentLayout.left),
                    turnPulse: turnPulse,
                    skippedPlayerID: skippedPlayerID
                )

                Spacer(minLength: 0)

                VStack(spacing: 2) {
                    Spacer(minLength: 0)
                    CenterTableView(
                        recentPile: pendingBurnPile.isEmpty
                            ? Array(engine.state.pile.suffix(4))
                            : Array(pendingBurnPile.suffix(4)),
                        pileCount: pendingBurnPile.isEmpty
                            ? engine.state.pile.count
                            : pendingBurnPile.count,
                        showDropTarget: dragCardID != nil,
                        burnEffect: burnEffect,
                        wildEffect: wildEffect,
                        reverseEffect: reverseEffect,
                        reverseDirection: reverseDirection,
                        canPickUpPile: canPickUpPile,
                        mustPickUpPile: mustPickUpPile,
                        onPickUpPile: onPickUpPile
                    )
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                SideOpponentView(
                    player: opponentLayout.right,
                    active: isCurrentPlayer(opponentLayout.right),
                    isNext: isNextPlayer(opponentLayout.right),
                    turnPulse: turnPulse,
                    skippedPlayerID: skippedPlayerID
                )
                .padding(.trailing, 20)
            }

            if let human = humanPlayer {
                PlayerAreaView(
                    human: human,
                    isMyTurn: isHumanTurn,
                    mustPickUp: mustPickUpPile,
                    openingCard: engine.openingCard,
                    turnPulse: turnPulse,
                    showHints: showHints,
                    skippedPlayerID: skippedPlayerID,
                    revealedFaceDownIndex: revealedFaceDownIndex,
                    selectedCards: $selectedCards,
                    dragCardID: $dragCardID,
                    dragOffset: $dragOffset,
                    canPlay: engine.canPlay,
                    onFaceDownTap: onFaceDownTap,
                    onCardTap: onCardTap,
                    onCardDoubleTap: onCardDoubleTap,
                    onDragStart: onDragStart,
                    onDragUpdate: onDragUpdate,
                    onDragEnd: onDragEnd,
                    onPickUpPile: onPickUpPile
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private var topOpponent: some View {
        let player = opponentLayout.top
        return TopOpponentView(
            player: player,
            active: isCurrentPlayer(player),
            isNext: isNextPlayer(player),
            turnPulse: turnPulse,
            skippedPlayerID: skippedPlayerID
        )
        .transition(.scale.combined(with: .opacity))
        .padding(.horizontal, 12)
        .padding(.top, 36)
    }

    private var humanPlayer: Player? {
        engine.state.players.first(where: { !$0.isAI })
    }

    private var isHumanTurn: Bool {
        engine.state.phase == .playing && !engine.state.currentPlayer.isAI
    }

    private var canPickUpPile: Bool {
        engine.state.phase == .playing
            && !engine.state.currentPlayer.isAI
            && engine.state.currentPlayer.playingFrom != .faceDown
            && !engine.state.pile.isEmpty
    }

    private var mustPickUpPile: Bool {
        canPickUpPile && !engine.hasPlayableCard(for: engine.state.currentPlayer)
    }

    private func isCurrentPlayer(_ player: Player) -> Bool {
        engine.state.currentPlayerIndex < engine.state.players.count
            && engine.state.players[engine.state.currentPlayerIndex].id == player.id
    }

    private func isNextPlayer(_ player: Player) -> Bool {
        let count = engine.state.players.count
        guard count > 0 else { return false }
        var idx = ((engine.state.currentPlayerIndex + engine.state.playDirection) % count + count) % count
        var attempts = 0
        while !engine.state.players[idx].hasCards && attempts < count {
            idx = ((idx + engine.state.playDirection) % count + count) % count
            attempts += 1
        }
        return engine.state.players[idx].id == player.id
    }
}

struct OpponentLayout {
    let left: Player
    let top: Player
    let right: Player

    init(players: [Player]) {
        let opponents = players.filter { $0.isAI }
        precondition(opponents.count == 3, "OpponentLayout requires exactly 3 AI opponents")
        left = opponents[0]
        top = opponents[1]
        right = opponents[2]
    }
}
