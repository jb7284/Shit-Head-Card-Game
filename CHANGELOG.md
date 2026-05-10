# Changelog

All notable changes to this project go here. Newest entries on top.

The format is loosely based on *Keep a Changelog* — every entry has a date, a short list of what changed, and a one-line "why" for each item.

---

## 2026-05-08 — First architecture pass

A round of code cleanup. **Gameplay is unchanged.** All changes are structural — renames, decoupling, and concurrency hygiene. A new architecture doc and this changelog were also added.

### Changed

- **Renamed `Card.isReset` → `Card.isWild`.**
  *Why:* The 2 doesn't reset the pile (only 10s and four-of-a-kinds burn). It's a wild card. The old name described a behavior the engine never actually had.

- **In-game message for a 2 now says "wild!" instead of "pile reset!".**
  *Why:* Same reason — the message was telling the player something that wasn't happening.

- **Replaced `PileClearReason` enum with a richer `GameEvent` enum** (`none`, `normal`, `wild`, `sevenPlayed`, `skip`, `reverse`, `burn`, `pickup`, `failedFlip`). The engine now sets `lastEvent` for every play, not just pile-clearing ones.
  *Why:* The visual flash for a 2 used to be triggered by string-matching the engine's message text (`message.contains("reset")`). That coupling would silently break the next time the wording changed. Now the View watches a typed event.

- **Renamed `resetEffect` / `triggerResetEffect()` → `wildEffect` / `triggerWildEffect()`** in `ContentView`.
  *Why:* Matches the new vocabulary; the visual itself (white circle pulse on a 2) is unchanged.

- **AI scheduling switched from `DispatchQueue.main.asyncAfter` to a cancellable `Task`** stored in `@State`. Each new turn cancels the previous task before scheduling.
  *Why:* The old version relied on stale-turn guards (capturing `expectedTurn` and `expectedPlayer` and bailing if they changed) to paper over the race. With cancellation, the race is gone instead of guarded.

- **Added `@MainActor` to `GameEngine`.**
  *Why:* The engine was always called from the main thread anyway; this lets the compiler enforce it instead of trusting future contributors to read the room.

- **Force-unwrap of the human player in `playerArea` replaced with a safe optional** via `@ViewBuilder`.
  *Why:* `engine.state.players.first(where: { !$0.isAI })!` would crash if a future change ever omitted the human. Now it just renders nothing — defensive but type-safe.

- **DRY'd suit characters.** Added `Suit.character` (plain Unicode glyph) to `Models.swift` and removed the duplicated lookups in `CardView` (`suitCharacter`) and `ContentView` (`suitChar`).
  *Why:* Three copies of the same switch statement was three places to forget when adding a suit (or fixing a glyph).

- **Removed the redundant `private var pile: [Card] { state.pile }` shorthand** inside `GameEngine`.
  *Why:* It was only used in two places and was hiding the fact that the pile lives on `state`. `state.pile` is clearer.

### Added

- `docs/ARCHITECTURE.md` — overview, file map, four Mermaid diagrams (system architecture, card-play sequence, game state machine, type relationships), key decisions, extension points, known issues.
- `README.md` — game rules, build instructions, project layout.
- `CHANGELOG.md` — this file.

### Notes

- Tests are still empty stubs. That's a known gap; not addressed in this pass.
- No new features. No UI redesign. The game plays identically to before.
