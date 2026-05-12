import SwiftUI
import AppKit

@MainActor
@Observable
class EffectCoordinator {
    var burnEffect = false
    var wildEffect = false
    var turnPulse = false

    var pendingBurnPile: [Card] = []
    var lastPileSnapshot: [Card] = []
    var burnedCards: [Card] = []
    var burnFlyProgress: CGFloat = 0

    var revealedFaceDownIndex: Int? = nil

    var skippedPlayerID: String? = nil
    private var skippedTask: Task<Void, Never>?

    var reverseEffect = false
    var reverseDirection: Int = 1
    var fourOfAKindEffect = false

    var rejectionShakeID: UUID? = nil
    var rejectionShakeTrigger: CGFloat = 0
    var rejectionMessage: String? = nil
    private var rejectionMessageTask: Task<Void, Never>?

    private let rejectionShakeDuration: TimeInterval = 0.45
    private let rejectionMessageDuration: TimeInterval = 1.5

    func handle(_ event: GameEvent, playFlightDuration: TimeInterval, isCurrentPlayerAI: Bool, playDirection: Int, isFourOfAKindBurn: Bool = false) {
        if event != .none && event != .reverse {
            withAnimation(.easeIn(duration: 0.3)) {
                reverseEffect = false
            }
        }

        switch event {
        case .burn:
            let wasFourOfAKind = isFourOfAKindBurn
            let burnDelay = playFlightDuration + 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + burnDelay) { [weak self] in
                self?.triggerBurnEffect()
                SoundManager.play(.burn)
                if wasFourOfAKind {
                    self?.triggerFourOfAKindEffect()
                }
            }
        case .wild:
            triggerWildEffect()
        case .pickup, .failedFlip:
            SoundManager.play(.pickup)
        case .skip:
            SoundManager.play(.skipped)
        case .reverse:
            reverseDirection = playDirection
            withAnimation(GameTheme.snappySpring) {
                reverseEffect = true
            }
            SoundManager.play(.reverse)
        case .joker:
            SoundManager.play(.joker)
        case .none, .normal, .sevenPlayed:
            break
        }
    }

    func setupPendingBurn(
        pre: FlightOrchestrator.StateSnapshot,
        post: FlightOrchestrator.StateSnapshot,
        lastEvent: GameEvent
    ) {
        guard lastEvent == .burn else { return }
        let allPostIDs = post.allCardIDs
        let playedCards = pre.players.flatMap { player in
            (player.hand + player.faceUp + player.faceDown).filter { !allPostIDs.contains($0.uid) }
        }
        pendingBurnPile = lastPileSnapshot + playedCards
    }

    func triggerRejectionFeedback(for card: Card, engine: GameEngine) {
        guard engine.difficulty == .easy else { return }

        rejectionShakeID = card.uid
        rejectionShakeTrigger = 0
        withAnimation(.linear(duration: rejectionShakeDuration)) {
            rejectionShakeTrigger = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + rejectionShakeDuration + 0.05) { [weak self] in
            if self?.rejectionShakeID == card.uid {
                self?.rejectionShakeID = nil
                self?.rejectionShakeTrigger = 0
            }
        }

        let reason = rejectionReason(for: card, engine: engine)
        rejectionMessageTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            rejectionMessage = reason
        }
        rejectionMessageTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.3)) {
                self?.rejectionMessage = nil
            }
        }
    }

    func showSkipped(playerID: String) {
        skippedTask?.cancel()
        withAnimation(GameTheme.snappySpring) {
            skippedPlayerID = playerID
        }
        skippedTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.4)) {
                self?.skippedPlayerID = nil
            }
        }
    }

    func restartTurnPulse() {
        turnPulse = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.turnPulse = true
        }
    }

    func triggerHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
    }

    func scheduleDrawHaptic(
        pre: FlightOrchestrator.StateSnapshot,
        post: FlightOrchestrator.StateSnapshot
    ) {
        guard let humanIdx = post.players.firstIndex(where: { !$0.isAI }),
              humanIdx < pre.players.count else { return }

        let prePlayer = pre.players[humanIdx]
        let postPlayer = post.players[humanIdx]
        let preHandSet = Set(prePlayer.hand.map { $0.uid })
        let preDrawSet = Set(prePlayer.drawPile.map { $0.uid })
        let drew = postPlayer.hand.contains {
            !preHandSet.contains($0.uid) && preDrawSet.contains($0.uid)
        }

        guard drew else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
    }

    func prepareForAction(savingPileFrom engine: GameEngine) {
        pendingBurnPile.removeAll()
        lastPileSnapshot = engine.state.pile
    }

    private func rejectionReason(for card: Card, engine: GameEngine) -> String {
        if engine.mustPlayUnderSeven {
            return "Must play 7 or lower \u{2014} a 7 was played"
        }
        if let top = engine.state.effectiveTopCard {
            return "Must play \(top.rank.label) or higher (or a 2 / 10)"
        }
        return "Can\u{2019}t play that card right now"
    }

    private func triggerBurnEffect() {
        let flyOffCards = pendingBurnPile.isEmpty
            ? Array(lastPileSnapshot.suffix(4))
            : Array(pendingBurnPile.suffix(4))

        withAnimation(.easeOut(duration: 0.6)) {
            burnEffect = true
            pendingBurnPile.removeAll()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.burnEffect = false
        }

        burnedCards = flyOffCards
        burnFlyProgress = 0
        withAnimation(.easeIn(duration: 0.55)) {
            burnFlyProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.burnedCards.removeAll()
            self?.burnFlyProgress = 0
        }
    }

    private func triggerFourOfAKindEffect() {
        withAnimation(GameTheme.snappySpring) {
            fourOfAKindEffect = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            withAnimation(.easeIn(duration: 0.4)) {
                self?.fourOfAKindEffect = false
            }
        }
    }

    private func triggerWildEffect() {
        withAnimation(.easeOut(duration: 0.15)) {
            wildEffect = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            withAnimation(.easeOut(duration: 0.15)) {
                self?.wildEffect = false
            }
        }
    }
}
