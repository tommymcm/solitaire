# Card Capture — Web Game Project Plan
> **For Gemini CLI** | Zig + Raylib + Emscripten → WASM

---

## Project Overview

Build **Card Capture**, a solitaire card game, as a browser-playable WASM application. The game logic and rendering are written entirely in **Zig**, compiled to WebAssembly via **Emscripten**, using **Raylib** for 2D rendering, input, audio, and animation. The output is a static bundle (`.html` + `.wasm` + `.data`) that can be self-hosted on any web server or dropped into itch.io.

The project includes:
- A fully playable **Card Capture** game mode with randomized decks
- An interactive **tutorial mode** that walks the player through rules step by step
- Balatro-inspired **card animations** (flip, slide, glow, screen shake)
- A clean main menu and game-over screen

---

## Card Capture Rules (Reference)

Card Capture is played with a standard 52-card deck. The goal is to capture as many cards as possible.

- Four cards are dealt face-up to a row (the "field")
- The player holds one card (drawn from the deck)
- If the player's card matches the **rank** of any field card, those cards are **captured** (removed from field, added to score pile)
- If the player's card matches the **suit** of any field card, those cards are also captured
- After playing, a new card is drawn
- If no captures are possible, the played card is added to the field
- Game ends when the deck is exhausted
- Score = number of captured cards (max 52)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Game language | Zig `0.13.0` (stable) |
| Rendering / Input / Audio | Raylib `5.0` (C library, via `@cImport`) |
| Zig→WASM compilation | Emscripten `3.1.x` (`emcc`) |
| Zig–Raylib bindings | `raylib-zig` (Not-Nik/raylib-zig, pinned to matching version) |
| Build system | Zig build system (`build.zig`) with Emscripten shell |
| Asset pipeline | Emscripten `--preload-file` for textures/audio |
| Hosting | Static files (any HTTP server) |

---

## Repository Structure

```
card-capture/
├── build.zig                  # Zig build script with Emscripten target
├── build.zig.zon              # Package manifest (raylib-zig dependency)
├── src/
│   ├── main.zig               # Entry point (CLI prototype -> Raylib loop)
│   ├── game.zig               # Core game state machine
│   ├── card.zig               # Card type, deck, shuffle
│   ├── rules.zig              # Capture logic, scoring
│   ├── tutorial.zig           # Tutorial state machine
│   ├── ui.zig                 # Menu, HUD, game-over screen
│   ├── animation.zig          # Tween engine, card animations
│   └── audio.zig              # Sound effect helpers
├── assets/
│   ├── cards/                 # PNG card faces (52 + back)
│   ├── fonts/                 # .ttf fonts
│   └── sounds/                # .wav/.ogg for deal, capture, etc.
├── web/
│   ├── shell.html             # Emscripten HTML shell (custom styled)
│   └── style.css              # Page chrome around the canvas
└── dist/                      # Build output (gitignored)
    ├── index.html
    ├── card-capture.wasm
    └── card-capture.data
```

---

## Phase 1 — Card Data Model & CLI Prototype

**Goal**: A complete, correct card/deck implementation playable in the terminal.

### Tasks

1. **`src/card.zig`** — define types:
   ```zig
   pub const Suit = enum { hearts, diamonds, clubs, spades };
   pub const Rank = enum { ace, two, three, ..., king };

   pub const Card = struct {
       suit: Suit,
       rank: Rank,
       pub fn format(...) void { // String representation for CLI }
   };

   pub const Deck = struct {
       cards: [52]Card,
       top: usize,
       // init(), shuffle(rng), draw(), remaining()
   };
   ```

2. **Shuffle** using Fisher-Yates with Zig's `std.rand.DefaultPrng`.

3. **`src/rules.zig`** — implement capture logic and unit tests.
   - `findCaptures(hand_card: Card, field: []?Card) []usize`
   - `applyPlay(state: *GameState, field_indices: []usize)`

4. **`src/main.zig` (CLI)** — Implement a basic `stdin`/`stdout` loop:
   - Print field: `[1] AH [2] 5D [3] -- [4] JS`
   - Print hand: `Your card: 5S`
   - Prompt: `Enter index to capture or 'p' to pass: `
   - Update state and repeat until deck empty.

### Verification
- `zig build run` plays a full game in the terminal.
- All unit tests pass (`zig test src/rules.zig`).

---

## Phase 2 — Project Scaffold & Build System (Raylib)

**Goal**: A blank Raylib window compiles and runs in the browser.

### Tasks

1. **Add raylib-zig dependency** in `build.zig.zon`.

2. **Update `build.zig`** with two targets:
   - Native target for local development (`zig build run`)
   - Emscripten target (`zig build -Dtarget=wasm32-emscripten`)

3. **`src/main.zig` (Raylib)** — Move CLI loop to a separate function or file, and implement minimal Raylib game loop:
   ```zig
   const rl = @import("raylib");
   pub fn main() !void {
       rl.initWindow(1024, 768, "Card Capture");
       // ... loop ...
   }
   ```

### Verification
- `zig build run` opens a native window with green background.
- `zig build -Dtarget=wasm32-emscripten` produces `dist/index.html`.

---

## Phase 3 — Game State Machine (Graphical)

**Goal**: Complete game flow wired up, playable via keyboard/mouse.

### Tasks

1. **`src/game.zig`** — `GameState` struct:
   - Manage phases: `.menu`, `.player_turn`, `.animating`, `.game_over`.
   - Bridge Phase 1 logic with Raylib input.

2. **`processInput()`** — reads mouse clicks on field cards; calls `rules.findCaptures`.

3. **`update(dt: f32)`** — transitions phases and draws new card from deck.

### Verification
- Stub out rendering with `rl.drawText` debug output showing state.
- Can play a full game to completion by clicking.

---

## Phase 4 — Card Rendering & Asset Pipeline

**Goal**: Real card art displayed on screen.

### Tasks

1. **Card assets** — generate a clean procedural card renderer or load PNGs.
2. **Layout constants** (`src/ui.zig`).
3. **`drawCard(...)`** and **`drawGameBoard(...)`**.

---

## Phase 5 — Animations

**Goal**: Balatro-feel card animations — smooth, juicy, satisfying.

### Tasks

1. **`src/animation.zig`** — lightweight tween engine.
2. **Animation sequences**: Deal, Draw, Flip, Capture, Shake.
3. **Glow effect** on capturable cards.

---

## Phase 6 — UI: Menu, HUD, Tutorial, Game Over

**Goal**: Complete UI flow from launch to game over.

### Tasks

1. **Main menu** and **Game over screen**.
2. **HUD**: Deck count, Score.
3. **Tutorial mode** (`src/tutorial.zig`) — scripted 8-step walkthrough.

---

## Phase 7 — Audio

**Goal**: Sound effects that reinforce the game feel.

### Tasks

1. **Sound events**: Deal, Capture, No match, Victory.
2. **`src/audio.zig`** — Load and play sound effects.

---

## Phase 8 — Polish & Web Integration

**Goal**: Production-ready web build.

### Tasks

1. **`web/shell.html`** and **`web/style.css`**.
2. **Optimize build** (`-O3`, `wasm-opt`).
3. **Save high score** to `localStorage`.

---

## Build Commands Reference

```bash
# Run CLI/Native
zig build run

# Run tests
zig test src/rules.zig

# Build for web
zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseFast
```

---

## Acceptance Criteria

The project is complete when:

- [ ] CLI Prototype is fully playable and follows all rules.
- [ ] `zig build run` launches a native window and plays a full game.
- [ ] `zig build -Dtarget=wasm32-emscripten` produces a working `dist/` bundle.
- [ ] Tutorial mode teaches all core mechanics.
- [ ] All 7 animation types are implemented and play at 60fps.
- [ ] Audio plays correctly in-browser.
- [ ] High score persists via localStorage.
- [ ] All unit tests pass.
- [ ] WASM binary is under 2MB.
