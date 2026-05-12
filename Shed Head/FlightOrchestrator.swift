import SwiftUI

@MainActor
@Observable
class FlightOrchestrator {
    var cardFrames: [UUID: CGRect] = [:]
    var pileFrame: CGRect = .zero
    var handCenterFrames: [String: CGRect] = [:]
    var drawPileFrames: [String: CGRect] = [:]
    var inFlightCardIDs: Set<UUID> = []
    var activeFlights: [CardFlight] = []

    let playStaggerSeconds: TimeInterval = 0.085
    let pickupStaggerSeconds: TimeInterval = 0.05
    let playFlightDuration: TimeInterval = 0.45
    let pickupFlightDuration: TimeInterval = 0.4
    let drawFlightDuration: TimeInterval = 0.4
    let drawStaggerSeconds: TimeInterval = 0.1

    struct StateSnapshot {
        let players: [Player]
        let pile: [Card]

        var allCardIDs: Set<UUID> {
            var ids = Set(pile.map { $0.uid })
            for p in players {
                ids.formUnion(p.hand.map { $0.uid })
                ids.formUnion(p.faceUp.map { $0.uid })
                ids.formUnion(p.faceDown.map { $0.uid })
                ids.formUnion(p.drawPile.map { $0.uid })
            }
            return ids
        }
    }

    func snapshot(from engine: GameEngine) -> StateSnapshot {
        StateSnapshot(players: engine.state.players, pile: engine.state.pile)
    }

    func spawnFlights(_ flights: [CardFlight]) {
        guard !flights.isEmpty else { return }
        inFlightCardIDs.formUnion(flights.map { $0.id })
        activeFlights.append(contentsOf: flights)
    }

    func handleFlightComplete(_ id: UUID) {
        inFlightCardIDs.remove(id)
        activeFlights.removeAll { $0.id == id }
    }

    func clearFlightsAfterAnimationsSettle(isStillFinished: @escaping () -> Bool) {
        let settleDelay = max(playFlightDuration, pickupFlightDuration) + 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) { [weak self] in
            guard isStillFinished() else { return }
            self?.activeFlights.removeAll()
            self?.inFlightCardIDs.removeAll()
        }
    }

    func reset() {
        activeFlights.removeAll()
        inFlightCardIDs.removeAll()
    }

    // MARK: - Flight Computation

    func computeFlights(pre: StateSnapshot, post: StateSnapshot) -> [CardFlight] {
        guard pileFrame != .zero else { return [] }
        let scale = pileFrame.width / 82

        var flights: [CardFlight] = []
        var playStagger: Int = 0
        var pickupStaggerByPlayer: [String: Int] = [:]

        let postPileSet = Set(post.pile.map { $0.uid })
        let prePileSet = Set(pre.pile.map { $0.uid })
        let allPostIDs = post.allCardIDs

        for (playerIndex, postPlayer) in post.players.enumerated() {
            guard playerIndex < pre.players.count else { continue }
            let prePlayer = pre.players[playerIndex]
            let isAI = prePlayer.isAI

            let postHandSet = Set(postPlayer.hand.map { $0.uid })
            let postFaceUpSet = Set(postPlayer.faceUp.map { $0.uid })
            let postFaceDownSet = Set(postPlayer.faceDown.map { $0.uid })

            for card in prePlayer.hand
            where !postHandSet.contains(card.uid) && (postPileSet.contains(card.uid) || !allPostIDs.contains(card.uid)) {
                guard let from = sourceFrame(for: card, player: prePlayer) else { continue }
                appendPlayFlight(card: card, from: from, startsFaceUp: !isAI,
                                 playStagger: &playStagger, flights: &flights)
            }

            for card in prePlayer.faceUp
            where !postFaceUpSet.contains(card.uid) && (postPileSet.contains(card.uid) || !allPostIDs.contains(card.uid)) {
                guard let from = sourceFrame(for: card, player: prePlayer) else { continue }
                appendPlayFlight(card: card, from: from, startsFaceUp: true,
                                 playStagger: &playStagger, flights: &flights)
            }

            for card in prePlayer.faceDown
            where !postFaceDownSet.contains(card.uid) && (postPileSet.contains(card.uid) || !allPostIDs.contains(card.uid)) {
                guard let from = sourceFrame(for: card, player: prePlayer) else { continue }
                appendPlayFlight(card: card, from: from, startsFaceUp: false,
                                 playStagger: &playStagger, flights: &flights)
            }

            let preHandSet = Set(prePlayer.hand.map { $0.uid })
            let pickedUp = postPlayer.hand.filter {
                !preHandSet.contains($0.uid) && prePileSet.contains($0.uid)
            }

            if !pickedUp.isEmpty {
                let rawDest = handCenterFrames[postPlayer.id] ?? cardFrames[postPlayer.hand.first?.uid ?? UUID()]
                if let dest = rawDest {
                    let cardW: CGFloat = isAI ? 30 * scale : 58 * scale
                    let cardH: CGFloat = isAI ? 40 * scale : 82 * scale
                    let to = CGRect(x: dest.midX - cardW / 2, y: dest.midY - cardH / 2,
                                    width: cardW, height: cardH)

                    for card in pickedUp {
                        let stagger = pickupStaggerByPlayer[postPlayer.id, default: 0]
                        pickupStaggerByPlayer[postPlayer.id] = stagger + 1
                        flights.append(CardFlight(
                            id: card.uid, card: card, from: pileFrame, to: to,
                            startsFaceUp: true, endsFaceUp: !isAI,
                            startDelay: TimeInterval(stagger) * pickupStaggerSeconds,
                            duration: pickupFlightDuration
                        ))
                    }
                }
            }

            let preDrawSet = Set(prePlayer.drawPile.map { $0.uid })
            let drawn = postPlayer.hand.filter {
                !preHandSet.contains($0.uid) && preDrawSet.contains($0.uid)
            }

            if !drawn.isEmpty, let drawFrom = drawPileFrames[postPlayer.id] {
                let rawDest = handCenterFrames[postPlayer.id] ?? cardFrames[postPlayer.hand.first?.uid ?? UUID()]
                if let dest = rawDest {
                    let cardW: CGFloat = isAI ? 30 * scale : 58 * scale
                    let cardH: CGFloat = isAI ? 40 * scale : 82 * scale
                    let to = CGRect(x: dest.midX - cardW / 2, y: dest.midY - cardH / 2,
                                    width: cardW, height: cardH)

                    let playDelay = TimeInterval(playStagger) * playStaggerSeconds + playFlightDuration
                    for (drawIndex, card) in drawn.enumerated() {
                        flights.append(CardFlight(
                            id: card.uid, card: card, from: drawFrom, to: to,
                            startsFaceUp: false, endsFaceUp: !isAI,
                            startDelay: playDelay + TimeInterval(drawIndex) * drawStaggerSeconds,
                            duration: drawFlightDuration
                        ))
                    }
                }
            }
        }

        return flights
    }

    private func sourceFrame(for card: Card, player: Player) -> CGRect? {
        cardFrames[card.uid] ?? handCenterFrames[player.id]
    }

    private func appendPlayFlight(
        card: Card, from: CGRect, startsFaceUp: Bool,
        playStagger: inout Int, flights: inout [CardFlight]
    ) {
        flights.append(CardFlight(
            id: card.uid, card: card, from: from, to: pileFrame,
            startsFaceUp: startsFaceUp, endsFaceUp: true,
            startDelay: TimeInterval(playStagger) * playStaggerSeconds,
            duration: playFlightDuration
        ))
        playStagger += 1
    }
}
