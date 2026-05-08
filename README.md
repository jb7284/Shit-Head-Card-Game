# $H!T Head

A SwiftUI card game for macOS. Play *Shithead* against 1-5 AI opponents — the last player holding cards is crowned the Sh\*t Head.

Single-player only. No accounts, no networking, no in-app purchases, no external dependencies.

![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![Platform](https://img.shields.io/badge/Platform-macOS%2014+-blue)

## Features

- **1-5 AI opponents** with custom portrait avatars and distinct personalities
- **3 difficulty levels** — Easy (with card highlighting hints), Medium, and Expert (strategic play with 7s, pile pressure, four-of-a-kind setups)
- **Drag-and-drop or tap** to play cards from a fan-spread hand
- **Responsive UI** that scales cleanly with window resizing — no blur, always crisp
- **Swap phase** at the start of each game to optimize your face-up cards
- **Visual effects** — burn animations, wild card flashes, amber pile glow
- **Gold-themed card backs** and draw piles with depth shadows

## How to Play

Each player starts with:

- **3 face-down cards** (hidden until played)
- **3 face-up cards** (visible, placed on top of face-down)
- **3 cards in hand** (refilled from the draw pile until it's empty)

Play through your zones in order: **hand -> face-up -> face-down**. On your turn, play a card equal to or higher than the top of the pile. If you can't play, pick up the entire pile.

### Special Cards

| Card | Effect |
|------|--------|
| **2** | **Wild** — plays on anything, resets the pile floor |
| **7** | **Transparent** — next player must play 7 or lower |
| **8** | **Skip** — next player loses their turn |
| **9** | **Reverse** — flips play direction |
| **10** | **Burn** — discards the pile, same player goes again |
| **Four of a kind** | **Burn** — four matching ranks on top of the pile burns it |

### Multi-Card Plays

Tap cards to select matching ranks, then play them together. Or double-tap a card to instantly play all matching-rank cards from your hand.

### Face-Down Cards

Blind flip — if the card is legal it plays, otherwise you take it and the entire pile.

### Winning

Get rid of all your cards and you're out. Last player holding cards loses.

## Build and Run

Open `$H!T Head.xcodeproj` in Xcode 15+ and run. Requires macOS 14+ (uses `@Observable` and `Task.sleep(for:)`).

```sh
xcodebuild -project '$H!T Head.xcodeproj' -scheme '$H!T Head' -destination 'platform=macOS' build
```

No Swift packages or external dependencies.

## Project Structure

```
$H!T Head/
├── _H_T_HeadApp.swift      # @main entry point
├── ContentView.swift        # Root view, game phase routing, overlays
├── GameEngine.swift         # Rules, turn management, AI strategies
├── Models.swift             # Card, Deck, Player, GameState, enums
├── GameTableView.swift      # Main game layout with opponent positioning
├── CardView.swift           # Card face/back rendering, pile landing zone
├── CenterTableView.swift    # Center pile area with effects
├── FanHandView.swift        # Fan-spread hand with drag gestures
├── PlayerAreaView.swift     # Player's table cards and draw pile
├── OpponentViews.swift      # Opponent layouts, avatar view, draw pile stack
├── SwapPhaseView.swift      # Pre-game card swap interface
├── StartScreenView.swift    # Title screen with difficulty/player selection
├── GameTheme.swift          # Game scale environment key, UI components
├── GameOverView.swift       # End-of-game overlay
├── RulesView.swift          # Rules sheet
├── SoundManager.swift       # Sound effects
└── Assets.xcassets/         # App icon + AI avatar portraits
```

## Tech Stack

- **SwiftUI** with `@Observable` (modern Observation framework)
- **Environment-based scaling** via custom `gameScale` key for responsive UI
- **Canvas** for procedural textures (card paper, felt background)
- **Zero external dependencies**
