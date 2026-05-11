# Codebase Review — $H!T Head

Date: 2026-05-11
Scope: full repository review for cleanup, maintainability, technical debt, architecture, and latent bugs. **No behavior, gameplay, or UI changes are proposed** — only structural cleanup. This document is a report plus a phased, low-risk refactor plan. Nothing here has been executed yet.

---

## 1. Overall assessment

The codebase is in reasonably good shape. There has already been one architecture pass (see `CHANGELOG.md`): the engine is `@MainActor`-isolated, AI scheduling uses a cancellable `Task`, events are typed (`GameEvent`), and game logic is split into `GameEngine` / `GameRules` / `GameDealer` / `AIPlayer`. The view layer separates `FlightOrchestrator` (card-flight animation) and `EffectCoordinator` (feedback/effects) from `ContentView`.

The remaining problems are mostly **duplication**, **a handful of oversized view files**, **scattered magic numbers that are secretly coupled**, **a project-organization inconsistency in the Xcode project**, and **a few fragile timing patterns**. None are emergencies; all are addressable incrementally without touching gameplay.

---

## 2. Findings

### 2.1 Architecture & organization

- **Source files split between two locations.** `GameOverView.swift`, `OpponentViews.swift`, `RulesView.swift`, and `SoundManager.swift` live at the **repo root**, while every other source file lives in `$H!T Head/`. The `$H!T Head/` group is a `PBXFileSystemSynchronizedRootGroup` (auto-includes any file in the folder), but the four root files are wired in individually via explicit `PBXBuildFile` / `PBXFileReference` / `PBXSourcesBuildPhase` entries (`$H!T Head.xcodeproj/project.pbxproj:10-13, 34-37, 93-96, 254-257`). Consequences:
  - The project layout is harder to reason about; `README.md:51-72` even *documents* all four as if they were inside `$H!T Head/`.
  - If someone naively moves one of them into `$H!T Head/` without editing the pbxproj, it will be compiled twice → duplicate-symbol build failure.
  - `README.md`'s "Project Structure" section is stale anyway — it omits `GameDealer.swift`, `GameEvents.swift`, `GameRules.swift`, `AIPlayer.swift`, `CardFeedback.swift`, `CardFlight.swift`, `EffectCoordinator.swift`, `FlightOrchestrator.swift`.
- **`docs/ARCHITECTURE.md` is referenced but does not exist.** `CHANGELOG.md:44-45` and the spirit of `README.md` both point at `docs/ARCHITECTURE.md`; there is no `docs/` directory. Dead reference.
- **Project/target name contains `$` and `!`.** `$H!T Head` / `$H!T Head.xcodeproj` / `_H_T_Head`. This breaks shell globbing and tooling (it bit me while reviewing). Out of scope to rename safely, but worth recording as known debt.
- **A few view files mix unrelated concerns** (see §2.3).

### 2.2 Repeated / redundant code

1. **Shimmer sweep is implemented ~5 times.** `SelectionChip.shimmerOverlay` (`GameTheme.swift:78-94`), `PrimaryGameButton.shimmerOverlay` (`GameTheme.swift:162-177`), `GoldShimmerText.shimmerOverlay` (`GameTheme.swift:211-226`), `WinnerShimmerModifier` (`GameOverView.swift:385-416`). All are: a 0→0.25(ish)-white linear gradient strip, `.offset(x: phase * (geo.size.width + shimmerWidth) - shimmerWidth)`, animated by `.linear(duration: 2.5).repeatForever(autoreverses: false)`. One `ShimmerOverlay` view (parameterized by strip width fraction and peak opacity) would replace all of them.
2. **The "gold gradient" is redefined at least 6 times** with slightly different RGB values: `SelectionChip.goldGradient`, `PrimaryGameButton.goldGradient`, `GoldShimmerText.goldGradient` (all in `GameTheme.swift`), `GoldJokerIcon.goldGradient` (`CardView.swift:470-480`), the title gradient in `StartScreenView.swift:98-108`, and the winner-emoji gradient in `GameOverView.swift:96-106`. Should be one or two named gradients on `GameTheme`.
3. **Card-back rendering exists 3 times.** `CardView.cardBack` (`CardView.swift:204-269`), `DecoCardBack` (`StartScreenView.swift:169-200`), and the per-layer rectangle in `DrawPileStack` (`OpponentViews.swift:404-431`) all draw the same brown gradient rounded-rect with a gold-ish stroke. The two simpler ones (`DecoCardBack`, `DrawPileStack` layer) could share a `CardBackRect` shape/view.
4. **Modulo "wrap to player index" arithmetic** `((i + dir * steps) % count + count) % count` is hand-written in at least four places: `GameEngine.afterPlay` skip (`GameEngine.swift:201`), `GameEngine.advanceTurn` twice (`GameEngine.swift:315, 319`), `GameTableView.isNextPlayer` twice (`GameTableView.swift:150, 153`), `AIPlayer.nextActivePlayer` (`AIPlayer.swift:285`). Easy to get an off-by-one wrong in one copy. Should be a single helper on `GameState` (e.g. `func index(after:steps:)`).
5. **"Next player with cards" logic is duplicated three times** with subtly different loops: `GameEngine.advanceTurn` (`GameEngine.swift:310-329`), `GameTableView.isNextPlayer` (`GameTableView.swift:147-157`), `AIPlayer.nextActivePlayer` (`AIPlayer.swift:281-291`). One `GameState.nextActiveIndex(from:steps:)` (returning the index that `advanceTurn` would land on) should be the single source of truth; the view's "is next?" and the AI's "who's next?" both call it.
6. **"Pick up the whole pile" is implemented twice in the engine.** `GameEngine.pickUpPile()` (`GameEngine.swift:251-261`) and the failed-flip branch of `playFaceDownAt` (`GameEngine.swift:146-155`) both do: append `state.pile` to the player's hand, `removeAll` the pile, `sortPlayableOrder` the hand, publish an event, `mustPlayUnderSeven = false`, set `message`, `advanceTurn()`. Differ only in event (`.pickup` vs `.failedFlip`) and message text. Extract a private helper.
7. **"Append cards to a player's hand and re-sort"** (`hand.append(contentsOf:); hand = GameRules.sortPlayableOrder(hand)`) appears in `pickUpPile`, `playFaceDownAt` failed-flip, and `giveCurrentPileTo` (`GameEngine.swift:288-292`). Trivial helper on `Player`.
8. **Active-zone `switch` is re-implemented in the engine** even though `Player.cards(in:)` exists. `GameEngine.playCards` (`GameEngine.swift:111-119`) writes `switch zone { case .hand: activeCards = player.hand … }` instead of `player.cards(in: zone)`.
9. **`humanPlayer` lookup** `players.first(where: { !$0.isAI })` is repeated in `ContentView` (`ContentView.swift:210-212`), `GameTableView` (`GameTableView.swift:123-125`), and as `firstIndex` in `GameEngine.swapCards` (`GameEngine.swift:38`) and `EffectCoordinator.scheduleDrawHaptic` (`EffectCoordinator.swift:141`). Add `GameState.humanPlayer` / `humanPlayerIndex`.
10. **`reportCardFrame(uid)` is always immediately followed by `hideIfInFlight(uid)`** on every card in `PlayerAreaView`, `FanHandView`, `OpponentViews`, `PileLandingZone`. Could be one `.trackedCard(uid)` modifier.
11. **`SkippedBadge` overlay is inlined** in `PlayerAreaView.body` (`PlayerAreaView.swift:65-73`) with the same transition that `SkippedOverlayModifier` (`OpponentViews.swift:57-72`) already encapsulates. The human area should use the same modifier.
12. **Side-opponent vs top-opponent table-card rows** (`OpponentViews.swift:93-116` and `OpponentViews.swift:149-173`) are near-identical 3-slot face-down/face-up `ZStack`s plus a draw-pile stack; the only difference is the face-up `offset(y: -8)` vs `offset(x: 8)`. Could be one `OpponentTableCards(player:faceUpOffset:)` view.
13. **`OpponentHandFan` vs `SideOpponentHandFan`** (`OpponentViews.swift:188-263`) are the same fan algorithm with horizontal vs vertical axis (and a 90° rotation). One view parameterized by axis would halve it.
14. **`mustPickUp` pickup buttons** appear twice with different copy/sizing: `CenterTableView.pickUpButton` (`CenterTableView.swift:121-146`) and `PlayerAreaView.mustPickUpOverlay` (`PlayerAreaView.swift:85-107`). Lower priority — they are intentionally styled differently — but the capsule+stroke+shadow recipe could be a small button style.

### 2.3 Spaghetti / oversized files / mixed responsibilities

- **`CardView.swift` — 654 lines, the largest file, and a grab-bag.** It contains: `CardView` + `CardViewStyle` (the actual card), `FeltTableBackground` (full-screen procedural felt), `PileLandingZone` (center pile), `GoldJokerIcon` (≈150 lines of `Canvas` path drawing for the joker face), and `DiamondShape`. `GoldJokerIcon` and `FeltTableBackground` in particular have nothing to do with `CardView` and should each be their own file. Splitting into `CardView.swift`, `TableBackground.swift`, `PileLandingZone.swift`, `GoldJokerIcon.swift` would make this navigable.
- **`GameOverView.swift` — 422 lines, also a grab-bag.** `GameOverOverlay`, the fly-swarm system (`FlySwarm`/`FlyView`/`FlyMotion`/`FlyPath`), the confetti system (`ConfettiBurst`/`ConfettiPiece`), **`JokerTargetPicker` (which is not a game-over view at all)**, and `WinnerShimmerModifier`. `JokerTargetPicker` should move out (e.g. `JokerTargetPicker.swift`); the celebration particle systems could become `Celebrations.swift`.
- **`ContentView.swift` — 438 lines.** It is the central coordinator and does: phase routing, swap-tap/drag handling, card selection logic, card drag handling, joker targeting, AI scheduling, and wiring `FlightOrchestrator` + `EffectCoordinator` together. The selection helpers (`toggleSelection`, `selectOnlyCompatible`, `handleCardTap/DoubleTap`, `beginCardDrag`/`updateCardDrag`/`endCardDrag`) form a self-contained "hand interaction" unit that could be pulled into a small `@Observable HandSelectionController` (state: `selectedCards`, `dragCardID`, `dragOffset`). That would shrink `ContentView` and make the drag/selection rules testable.
- **`ContentView.triggerAI()` is the spaghettiest spot** (`ContentView.swift:400-433`): magic delay numbers (`1800` / `75` / `1200` / `1500`), recursive self-scheduling, and a special-cased joker follow-up nested inside the same `Task`. Worth at least pulling the delay choice into a named function and the magic numbers into named constants; ideally the joker follow-up becomes its own step.
- **`GameEngine.afterPlay` (`GameEngine.swift:168-216`)** is a long if/else chain whose side effects (`mustPlayUnderSeven` set mid-method, `message` built in several branches, early returns for joker/burn/skip) are order-sensitive. It is currently readable, but it's the function most likely to be broken by a careless edit. A short doc comment describing the required order, or splitting the per-card-effect branches into small private methods, would harden it.

### 2.4 Technical debt / naming / fragile assumptions

- **`Player.playingFrom` returns `.hand` when the draw pile is non-empty** (`Models.swift:141-146`) — there is no `.drawPile` case in `CardZone`, so this is a deliberate fib that callers rely on. Similarly `Player.activeCards` returns `[]` while the draw pile is non-empty (`Models.swift:134-139`). Both are correct given how they're used, but they need a comment; today a reader has to reverse-engineer the intent.
- **`GameEvent` carries no payload, so the engine needs companion one-shot flags.** `lastBurnWasFourOfAKind` (`GameEngine.swift:14`) and `skippedPlayerID` (`GameEngine.swift:13`) exist only to ferry extra info alongside `.burn` / `.skip` to the view's `onChange(of: eventSerial)`. Making `GameEvent` carry associated values (`.burn(fourOfAKind: Bool)`, `.skip(skippedPlayerID: String?)`) would remove the flags and the timing risk of reading them at the wrong moment. This is a behavior-neutral refactor.
- **`DispatchQueue.main.asyncAfter` everywhere for effect cleanup, none cancellable, and the coordinators are never recreated.** `EffectCoordinator` and `FlightOrchestrator` are `@State` in `ContentView` (`ContentView.swift:7-8`) and live for the app's lifetime; `startGame()` calls `flights.reset()` but does **not** reset `effects`. There are ~10 fire-and-forget `asyncAfter` closures (`EffectCoordinator.swift:44, 91, 128, 154, 183, 192, 202, 213`, `GameOverView.runSequence` `GameOverView.swift:155-174`, `FlyingCardView.onAppear` `CardFlight.swift:171-178`). They use `[weak self]` so they won't crash, but a pending burn-fly animation or `turnPulse` from the previous hand can fire a moment into a new game. Low-severity visual glitch; the clean fix is to move all timed cleanup onto cancellable `Task`s (matching the pattern already used for `skippedTask`/`rejectionMessageTask`) and cancel them in a `reset()` that `startGame()` calls.
- **`GameState.loser` returns `players.first(where: { $0.hasCards })`** (`Models.swift:213-216`) — correct only because `checkGameOver` ends the game when ≤1 player has cards. Fine, but it's an invariant worth a comment.
- **`FlightOrchestrator` hard-codes `82` as the design pile width** to derive `scale = pileFrame.width / 82` (`FlightOrchestrator.swift:69`) and again as `28` magic-number cousins for card sizes (`30`/`40`/`58`/`82` in `FlightOrchestrator.swift:117-118, 143-144`). The same `82`/`108` pile dimensions reappear in `PileLandingZone` (`CardView.swift:426`), `CenterTableView` (`CenterTableView.swift:116`), and card sizes `58`/`82`/`38`/`54`/`30`/`40` are scattered across `CardViewStyle` (`CardView.swift:313-332`), `FlyingCardView` (`CardFlight.swift:126-127`), `FanMetrics` (`FanHandView.swift:110, 119`), `PlayerAreaView` (`PlayerAreaView.swift:39`). If any of these drift apart, flights land in the wrong place. They should be named constants in one place (e.g. `CardMetrics` enum) that everyone references.
- **`README.md` "Project Structure" and "GameEngine.swift # Rules, turn management, AI strategies" are out of date** (AI is in `AIPlayer.swift`, dealing in `GameDealer.swift`, etc.).
- **Tests are essentially absent** — `_H_T_HeadTests.swift` has two tests; the UI test files are template stubs. `CHANGELOG.md:50` already acknowledges this. Not "debt to remove," but the refactors below are much safer with a few characterization tests of `GameEngine` first (see plan).
- **`@MainActor enum SoundManager` keeps a single `AVAudioPlayerNode` and calls `node.stop()` before each sound** (`SoundManager.swift:20-28`) — overlapping sounds cut each other off. Probably intentional/acceptable for this game; noted only so it isn't mistaken for a bug later.
- **Minor:** `Deck.draw(_ n: Int)` shadows a local `count` (`Models.swift:109-114`); `_H_T_HeadApp.swift` still has the Xcode template header comment.

### 2.5 Bugs / likely future failures

- **Stale timed effects across a new game** — described in §2.4. The realistic symptom: start a new game right as a burn/skip/turn-pulse animation from the prior hand is mid-flight and you'll see a stray flash. Severity: cosmetic.
- **`OpponentLayout` hard-asserts exactly 3 AI opponents** via `precondition` (`GameTableView.swift:167`). `GameEngine.startNewGame` is always called with `playerCount: 4` from `ContentView.startGame` (`ContentView.swift:221`), so this holds today — but `GameDealer.newGameState` clamps `playerCount` to `2...6` (`GameDealer.swift:5`) and `StartScreenView` only exposes difficulty (no player-count picker), so the 2/3/5/6-player paths are reachable in code but would crash the table view. Either remove the dead clamp/parameter flexibility or make `GameTableView` tolerate other counts. (Pure cleanup; pick one direction.)
- **`triggerAI()` recursion depth** — each AI turn schedules the next via a fresh `Task`; with a burn that makes the same player "go again," `burnPile` calls `advanceTurn()` which bumps `turnNumber`, which re-fires `triggerAI()` via `onChange` (`ContentView.swift:85-87`). This terminates fine in practice, but the control flow (engine mutating `turnNumber` → SwiftUI `onChange` → new `Task` → engine again) is indirect enough to be worth a comment.
- **`playCard`/`playCards` silently `return` on any validation failure** (`GameEngine.swift:96-104, 117-119`). For AI-driven calls a silent no-op could in principle wedge a turn; in practice the AI only ever passes cards it just filtered as playable, so it's safe — but a `assertionFailure` in debug builds would catch a future AI bug instead of producing a frozen turn.

---

## 3. Safe refactor plan

Principles: each step is independently shippable, compiles on its own, and is behavior/UI-neutral. Order is chosen so the riskier moves happen after a safety net is in place. **Do not** combine multiple steps into one commit.

### Phase 0 — Safety net & zero-risk cleanup (do first)

0.1. **Add characterization tests for `GameEngine`** (no production code changed). Cover: a normal play advances the turn; a 7 sets `mustPlayUnderSeven`; an 8 skips; a 9 flips `playDirection`; a 10 burns and the same player goes again; four-of-a-kind burns; `pickUpPile` moves the pile and advances; a failed face-down flip returns the pile + flip card to the flipper; joker sets `pendingJokerPlayerIndex` and `assignJokerPile` hands the pile over; `checkGameOver` ends with the right loser. These lock current behavior so later phases can't silently regress.
0.2. **Update `README.md`** Project Structure to match reality (list all files; note the four at repo root), and **fix `CHANGELOG.md`'s reference to `docs/ARCHITECTURE.md`** (either drop the reference or add the doc). Docs-only.
0.3. **Remove the Xcode template header comment** in `_H_T_HeadApp.swift`. Cosmetic.

### Phase 1 — Pure extractions in the model/engine layer (low risk, well covered by Phase 0 tests)

1.1. Add to `GameState`: `humanPlayerIndex` / `humanPlayer`, `index(after:steps:)` (the wraparound math), and `nextActiveIndex(from:steps:)` (the "skip card-less players" walk). Add to `Player`: `mutating func addToHand(_ cards:)` that appends and re-sorts. **Do not change call sites yet** — just introduce the API.
1.2. Switch existing call sites to the new helpers, one file per commit: `GameEngine.advanceTurn`/`afterPlay`, then `GameTableView.isNextPlayer`, then `AIPlayer.nextActivePlayer`. Each commit must keep tests green.
1.3. In `GameEngine`: replace the inline active-zone `switch` in `playCards` with `player.cards(in: zone)`; extract the duplicated "take the whole pile" body of `pickUpPile` and the `playFaceDownAt` failed-flip branch into one private `pickUpEntirePile(event:message:)`.
1.4. Add doc comments to `Player.playingFrom`, `Player.activeCards`, and `GameState.loser` explaining the invariants they assume.

### Phase 2 — Theme/UI de-duplication (low risk; visual diff should be empty)

2.1. Add `GameTheme.goldGradient` (and a second variant if two genuinely-different golds are needed). Point `SelectionChip`, `PrimaryGameButton`, `GoldShimmerText`, `GoldJokerIcon`, the `StartScreenView` title, and the `GameOverView` winner emoji at it — **only where the colors are already effectively identical**; leave any intentionally-different gradient alone and note it.
2.2. Add a `ShimmerOverlay` view (params: strip-width fraction, peak opacity, duration) and a `.shimmer(...)` modifier. Replace the four hand-rolled shimmer implementations with it.
2.3. Add a shared `.trackedCard(_ uid:)` modifier = `reportCardFrame` + `hideIfInFlight`. Replace the paired calls.
2.4. Use `SkippedOverlayModifier` (already in `OpponentViews.swift`) in `PlayerAreaView` instead of the inlined `SkippedBadge` overlay.
2.5. Introduce a `CardMetrics` enum with the canonical card/pile dimensions (`58×82` standard, `38×54` small, `30×40` opponent, `82×108` landing zone) and have `CardViewStyle`, `FlyingCardView`, `FanMetrics`, `PlayerAreaView`, `PileLandingZone`, `CenterTableView`, and `FlightOrchestrator` reference it. This removes the hidden coupling on the literal `82`.

### Phase 3 — File splits (risk is only "did I move the right symbols"; no logic edits)

3.1. **Decide and execute the repo-root file relocation.** Recommended: move `GameOverView.swift`, `OpponentViews.swift`, `RulesView.swift`, `SoundManager.swift` into `$H!T Head/`, and in the same commit delete their `PBXBuildFile` (`:10-13`), `PBXFileReference` (`:34-37`), `PBXGroup` children (`:93-96`), and `PBXSourcesBuildPhase` entries (`:254-257`) from `project.pbxproj` so the synchronized group is the only thing that includes them. Verify a clean build (no duplicate symbols, all four still compiled). If editing the pbxproj is judged too risky to do by hand, the fallback is to leave them where they are and just fix the `README.md` description — but the split is the better end state. Do this as its own commit with nothing else in it.
3.2. Split `CardView.swift` → keep `CardView` + `CardViewStyle` + `DiamondShape`; move `FeltTableBackground` to `TableBackground.swift`, `PileLandingZone` to `PileLandingZone.swift`, `GoldJokerIcon` to `GoldJokerIcon.swift`.
3.3. Split `GameOverView.swift` → keep `GameOverOverlay`; move `FlySwarm`/`ConfettiBurst` (+ their private helpers) to `Celebrations.swift`, `JokerTargetPicker` to `JokerTargetPicker.swift`, `WinnerShimmerModifier` to `GameTheme.swift` (or fold it into the new `ShimmerOverlay`).
3.4. Optionally pull `OpponentTableCards` and a single axis-parameterized `OpponentHandFan` out of `OpponentViews.swift` to remove the side/top duplication.

### Phase 4 — Behavior-neutral engine/view-state refactors (do last, with Phase 0 tests as the guardrail)

4.1. **Give `GameEvent` associated values** (`.burn(fourOfAKind: Bool)`, `.skip(skippedPlayerID: String?)`) and delete `lastBurnWasFourOfAKind` / `skippedPlayerID` from `GameEngine`. Update `ContentView.onChange(of: eventSerial)` and `EffectCoordinator.handle` to read the payload. Tests must still pass.
4.2. **Make all timed effect cleanup cancellable.** In `EffectCoordinator`, replace the `DispatchQueue.main.asyncAfter` cleanups with stored `Task`s (mirroring `skippedTask`); add a `reset()` that cancels them all and have `ContentView.startGame()` call `effects.reset()` alongside `flights.reset()`. Same treatment for `FlyingCardView`/`GameOverView` is optional since those views are recreated per game-over.
4.3. **Extract `HandSelectionController`** (`@Observable`, owns `selectedCards`/`dragCardID`/`dragOffset` and the `toggleSelection`/`selectOnlyCompatible`/tap/double-tap/drag-begin-update-end logic) out of `ContentView`. `ContentView` keeps lifecycle, phase routing, AI scheduling, and the `animateAction` glue. This is the largest single change and should land alone.
4.4. **Tame `triggerAI()`**: name the delay constants, extract `aiDelayMilliseconds(...)`, and lift the joker follow-up into its own scheduled step rather than a nested block. No timing changes — just legibility.
4.5. **Resolve the player-count ambiguity** (`GameDealer` clamps to 2...6 but `OpponentLayout` requires exactly 3 AI and the UI only ever passes 4): either lock the engine to 4 players and drop the unused flexibility, or make `GameTableView`/`OpponentLayout` handle other counts. Pick the direction that matches product intent; until then, at minimum convert `OpponentLayout`'s `precondition` into a clearer comment about the assumption.

### Out of scope (record, don't do now)

- Renaming the Xcode project away from `$H!T Head` / `_H_T_Head`.
- Reworking `SoundManager` to allow overlapping sounds.
- Writing `docs/ARCHITECTURE.md` from scratch (unless you want it; Phase 0.2 just removes the dangling reference).

---

## 4. Quick reference — biggest wins for least risk

| Win | Effort | Risk |
|-----|--------|------|
| Phase 0.1 characterization tests | M | none |
| Phase 1.1–1.2 `GameState` index/lookup helpers | S | low |
| Phase 2.1–2.2 gold gradient + `ShimmerOverlay` | S | low |
| Phase 2.5 `CardMetrics` constants | S | low (removes a real hidden coupling) |
| Phase 3.2–3.3 split `CardView.swift` / `GameOverView.swift` | M | low |
| Phase 3.1 relocate the four root files + pbxproj edit | S | medium (touches `project.pbxproj`) |
| Phase 4.1 `GameEvent` payloads | M | medium (covered by Phase 0 tests) |
| Phase 4.3 extract `HandSelectionController` | L | medium |
