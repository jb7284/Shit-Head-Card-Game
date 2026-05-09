import SwiftUI

struct GameTableView: View {
    let engine: GameEngine
    @Binding var selectedCards: [Card]
    @Binding var dragCardID: UUID?
    @Binding var dragOffset: CGSize

    let burnEffect: Bool
    let wildEffect: Bool
    let turnPulse: Bool
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
            if !opponentLayout.top.isEmpty {
                topOpponentsRow
                    .padding(.bottom, 4)
            }

            HStack(spacing: 0) {
                if let left = opponentLayout.left {
                    SideOpponentView(player: left, active: isCurrentPlayer(left), isNext: isNextPlayer(left), turnPulse: turnPulse)
                }

                Spacer(minLength: 0)

                VStack(spacing: 2) {
                    Spacer(minLength: 0)
                    CenterTableView(
                        topCard: engine.state.topCard,
                        pileCount: engine.state.pile.count,
                        showDropTarget: dragCardID != nil,
                        burnEffect: burnEffect,
                        wildEffect: wildEffect,
                        canPickUpPile: canPickUpPile,
                        mustPickUpPile: mustPickUpPile,
                        onPickUpPile: onPickUpPile
                    )
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                if let right = opponentLayout.right {
                    SideOpponentView(player: right, active: isCurrentPlayer(right), isNext: isNextPlayer(right), turnPulse: turnPulse)
                        .padding(.trailing, 20)
                }
            }

            if let human = humanPlayer {
                PlayerAreaView(
                    human: human,
                    isMyTurn: isHumanTurn,
                    turnPulse: turnPulse,
                    showHints: showHints,
                    selectedCards: $selectedCards,
                    dragCardID: $dragCardID,
                    dragOffset: $dragOffset,
                    canPlay: engine.canPlay,
                    onFaceDownTap: onFaceDownTap,
                    onCardTap: onCardTap,
                    onCardDoubleTap: onCardDoubleTap,
                    onDragStart: onDragStart,
                    onDragUpdate: onDragUpdate,
                    onDragEnd: onDragEnd
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private var topOpponentsRow: some View {
        HStack(spacing: 6) {
            ForEach(opponentLayout.top) { ai in
                TopOpponentView(player: ai, active: isCurrentPlayer(ai), isNext: isNextPlayer(ai), turnPulse: turnPulse)
                    .transition(.scale.combined(with: .opacity))
            }
        }
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
    let top: [Player]
    let left: Player?
    let right: Player?

    init(players: [Player]) {
        let opponents = players.filter { $0.isAI }
        switch opponents.count {
        case 1, 2:
            top = opponents
            left = nil
            right = nil
        case 3:
            top = [opponents[1]]
            left = opponents[0]
            right = opponents.last
        case 4:
            top = [opponents[1], opponents[2]]
            left = opponents[0]
            right = opponents.last
        case 5:
            top = [opponents[1], opponents[2], opponents[3]]
            left = opponents[0]
            right = opponents.last
        default:
            top = opponents
            left = nil
            right = nil
        }
    }
}
