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
│   ├── main.zig               # Entry point, game loop
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

## Phase 1 — Project Scaffold & Build System

**Goal**: A blank Raylib window compiles and runs in the browser.

### Tasks

1. **Initialize Zig project**
   ```bash
   zig init
   ```

2. **Add raylib-zig dependency** in `build.zig.zon`:
   ```zig
   .dependencies = .{
       .raylib_zig = .{
           .url = "https://github.com/Not-Nik/raylib-zig/archive/<COMMIT>.tar.gz",
           .hash = "<HASH>",
       },
   },
   ```

3. **Write `build.zig`** with two targets:
   - Native target for local development (`zig build run`)
   - Emscripten target (`zig build -Dtarget=wasm32-emscripten`) that invokes `emcc`, links Raylib's web port, and outputs to `dist/`

4. **Emscripten flags** to set in build:
   ```
   -sUSE_GLFW=3
   -sASYNCIFY
   -sALLOW_MEMORY_GROWTH=1
   -sINITIAL_MEMORY=67108864
   --preload-file assets
   --shell-file web/shell.html
   ```

5. **`src/main.zig`** — minimal game loop:
   ```zig
   const rl = @import("raylib");

   pub fn main() void {
       rl.initWindow(1024, 768, "Card Capture");
       rl.setTargetFPS(60);
       while (!rl.windowShouldClose()) {
           rl.beginDrawing();
           rl.clearBackground(rl.Color.dark_green);
           rl.drawText("Card Capture", 400, 350, 32, rl.Color.white);
           rl.endDrawing();
       }
       rl.closeWindow();
   }
   ```

6. **`web/shell.html`** — minimal Emscripten shell with canvas centered, dark background, no default Emscripten UI chrome.

### Verification
- `zig build run` opens a native window with green background
- `zig build -Dtarget=wasm32-emscripten` produces `dist/index.html`
- Opening `dist/index.html` via `python3 -m http.server` shows the same window in browser

---

## Phase 2 — Card Data Model & Deck Logic

**Goal**: A complete, correct card/deck implementation with shuffle and deal.

### Tasks

1. **`src/card.zig`** — define types:
   ```zig
   pub const Suit = enum { hearts, diamonds, clubs, spades };
   pub const Rank = enum { ace, two, three, ..., king };

   pub const Card = struct {
       suit: Suit,
       rank: Rank,
       face_up: bool = false,
   };

   pub const Deck = struct {
       cards: [52]Card,
       top: usize,
       // init(), shuffle(rng), draw(), remaining()
   };
   ```

2. **Shuffle** using Fisher-Yates with Zig's `std.rand.DefaultPrng` seeded from `std.time.milliTimestamp()`.

3. **`src/rules.zig`** — implement:
   - `findCaptures(hand_card: Card, field: []Card) []usize` — returns indices of field cards that would be captured
   - `applyPlay(state: *GameState, field_indices: []usize)` — moves cards to capture pile or adds to field
   - `isGameOver(state: GameState) bool`
   - `calcScore(state: GameState) u32`

4. **Unit tests** in `src/rules.zig`:
   ```zig
   test "rank match captures" { ... }
   test "suit match captures" { ... }
   test "no match adds to field" { ... }
   test "full field of 4 overflow" { ... }
   ```
   Run with `zig test src/rules.zig`.

### Verification
- All unit tests pass (`zig test src/rules.zig`)
- Can deal a full game programmatically and reach game-over state

---

## Phase 3 — Game State Machine

**Goal**: Complete game flow wired up, playable via keyboard/mouse without graphics.

### Tasks

1. **`src/game.zig`** — `GameState` struct:
   ```zig
   pub const Phase = enum {
       menu,
       tutorial,
       dealing,
       player_turn,
       animating,
       game_over,
   };

   pub const GameState = struct {
       phase: Phase,
       deck: Deck,
       field: [4]?Card,       // field slots, nullable
       hand: ?Card,           // current held card
       captured: u32,         // score
       turn: u32,
       rng: std.rand.DefaultPrng,
       // init(), newGame(), processInput(), update()
   };
   ```

2. **`processInput()`** — reads mouse clicks on field cards; determines which field slot was clicked; calls `rules.findCaptures` and `rules.applyPlay`; transitions phase to `.animating` before `.player_turn`.

3. **`update(dt: f32)`** — advances animation timers, transitions phases when animations complete, draws new card from deck.

4. **Tutorial state machine** in `src/tutorial.zig`:
   - Array of `TutorialStep` tagged unions:  
     `highlight_card`, `show_text_bubble`, `wait_for_click`, `force_play`, `advance`
   - Fixed scripted deck so the tutorial always plays the same sequence
   - Each step has explanatory text and an optional highlighted card index

### Verification
- Stub out rendering with `rl.drawText` debug output showing state
- Can play a full game to completion by clicking

---

## Phase 4 — Card Rendering & Asset Pipeline

**Goal**: Real card art displayed on screen, basic layout working.

### Tasks

1. **Card assets** — if no art assets are available, **generate a clean procedural card renderer** in Zig/Raylib:
   - Draw rounded rectangles with `rl.drawRectangleRounded`
   - Draw suit symbols (♥ ♦ ♣ ♠) as Unicode text with a loaded TTF font
   - Draw rank text (A, 2–10, J, Q, K)
   - Red/black color scheme
   - Card back: dark green with a simple geometric pattern drawn procedurally

2. If using PNG assets:
   - Load all 52 card textures + back texture at startup via `rl.loadTexture`
   - Store in a `[52]rl.Texture2D` array indexed by `suit * 13 + rank`
   - Unload on exit

3. **Layout constants** (`src/ui.zig`):
   ```zig
   pub const CARD_W: f32 = 90;
   pub const CARD_H: f32 = 126;
   pub const FIELD_Y: f32 = 300;
   pub const FIELD_X_START: f32 = 280;
   pub const FIELD_GAP: f32 = 120;
   pub const HAND_X: f32 = 512;
   pub const HAND_Y: f32 = 560;
   ```

4. **`drawCard(card: Card, x: f32, y: f32, scale: f32, alpha: f32)`** — renders a card at position, supports scaling and alpha for animations.

5. **`drawGameBoard(state: GameState)`** — renders field slots (empty slot outlines), field cards, hand card, deck counter, score.

### Verification
- Full game board visible with all cards rendering correctly
- Empty slot outlines show when field has fewer than 4 cards

---

## Phase 5 — Animations

**Goal**: Balatro-feel card animations — smooth, juicy, satisfying.

### Tasks

1. **`src/animation.zig`** — lightweight tween engine:
   ```zig
   pub const Easing = enum { linear, ease_out_quad, ease_out_back, ease_in_out_cubic };

   pub const Tween = struct {
       from: f32, to: f32,
       t: f32,       // 0..1 progress
       duration: f32,
       easing: Easing,
       // tick(dt), value(), done()
   };

   pub const CardAnim = struct {
       card: Card,
       x: Tween, y: Tween,
       scale: Tween,
       alpha: Tween,
       rotation: Tween,
   };
   ```

2. **Animation sequences to implement**:

   | Event | Animation |
   |---|---|
   | Deal card to field | Slide from deck position to field slot, `ease_out_back` |
   | Draw card to hand | Slide from deck to hand position, slight scale-up |
   | Card flip | Scale X from 1→0→1 with texture swap at midpoint |
   | Capture | Cards fly to score pile top-right, scale down, fade out |
   | No capture (add to field) | Card slides from hand to empty field slot |
   | Invalid click | Hand card shakes left-right (ease_in_out_cubic, 3 oscillations) |
   | Game over | All remaining field cards fade out, score counter ticks up |

3. **Glow effect on capturable cards**: When player holds a card, highlight capturable field cards with a pulsing colored rectangle drawn behind the card (`rl.drawRectangleRounded` with alpha cycling via `sin(time * 3.0) * 0.3 + 0.5`).

4. **Screen shake**: On a large capture (3+ cards), apply a `shake_offset` to the render camera for ~0.3s, decaying with `ease_out_quad`.

5. **Animation queue**: `GameState` holds a `[]CardAnim` list; `update()` ticks all active animations; phase stays `.animating` until list is empty.

### Verification
- All 7 animation types play correctly
- Game logic only advances after animations complete
- 60fps maintained (profile with `rl.getFPS()` overlay)

---

## Phase 6 — UI: Menu, HUD, Tutorial, Game Over

**Goal**: Complete UI flow from launch to game over.

### Tasks

1. **Main menu** (`phase == .menu`):
   - Title "Card Capture" in large display font
   - Two buttons: **Play** and **Tutorial**
   - Animated card fan in background (5 cards fanned out, slowly rotating)
   - Click detection via `rl.checkCollisionPointRec`

2. **HUD** (during gameplay):
   - Top-left: deck remaining count + small deck icon
   - Top-right: score (captured count) with a small trophy icon
   - Bottom: subtle turn counter

3. **Tutorial mode** (`src/tutorial.zig`):
   - Scripted 8-step walkthrough:
     1. Here is your hand card
     2. Here is the field
     3. This card matches by rank — click it to capture
     4. (player clicks) — great, captured!
     5. This card matches by suit — click it
     6. (player clicks) — both suit and rank can match at once
     7. No match — your card goes to the field
     8. Tutorial complete — play a full game?
   - Each step: darken non-relevant cards (alpha 0.4), show text bubble, highlight relevant card with glow
   - Arrow sprite or pointer drawn toward highlighted element

4. **Game over screen**:
   - Score displayed large: "You captured 38 cards"
   - Rating: Poor / Good / Great / Perfect based on score thresholds (< 20 / 20–34 / 35–44 / 45–52)
   - Two buttons: **Play Again** and **Main Menu**
   - Captured cards fan out as a victory display

### Verification
- Full flow: Menu → Tutorial → complete → Menu → Play → Game Over → Play Again works without crashes
- Tutorial cannot be skipped mid-step accidentally

---

## Phase 7 — Audio

**Goal**: Sound effects that reinforce the game feel.

### Tasks

1. **Sound events**:
   | Event | Sound |
   |---|---|
   | Card dealt | Short soft thwap |
   | Capture | Satisfying collect chime |
   | No match | Subtle thud |
   | Large capture (3+) | Fanfare sting |
   | Game over (good score) | Victory melody |
   | Game over (poor score) | Sad trombone |
   | Button click | Tick |

2. Use free CC0 card sound assets (e.g. from freesound.org) or synthesize procedurally.

3. **`src/audio.zig`**:
   ```zig
   pub const Sounds = struct {
       deal: rl.Sound,
       capture: rl.Sound,
       no_match: rl.Sound,
       big_capture: rl.Sound,
       // loadAll(), unloadAll(), play(sound)
   };
   ```

4. Initialize audio device with `rl.initAudioDevice()` at startup; handle WASM autoplay restrictions (Emscripten requires user interaction before audio starts — trigger `rl.initAudioDevice()` on first mouse click if needed).

### Verification
- All sounds play at correct moments
- No audio on page load before first interaction (browser policy)
- Audio doesn't break WASM build

---

## Phase 8 — Polish & Web Integration

**Goal**: Production-ready web build.

### Tasks

1. **`web/shell.html`** — custom shell:
   - Remove all default Emscripten UI
   - Dark background (`#1a1a2e`) surrounding canvas
   - Canvas centered, max-width 1024px
   - Loading bar styled to match game aesthetic
   - Mobile viewport meta tag

2. **`web/style.css`**:
   - Body background matches game felt color
   - Canvas has subtle box shadow
   - No scrollbars

3. **Optimize build**:
   ```bash
   emcc ... -O3 -flto --closure 1
   wasm-opt dist/card-capture.wasm -O3 -o dist/card-capture.wasm
   ```

4. **Target window size handling**:
   - Use `rl.setWindowSize` + Emscripten canvas resize callback to handle browser window resize
   - Maintain 4:3 aspect ratio with letterboxing

5. **Save high score** to `localStorage` via a tiny JS interop function:
   ```zig
   // in main.zig
   extern fn saveHighScore(score: u32) void;
   extern fn loadHighScore() u32;
   ```
   ```javascript
   // in shell.html
   mergeInto(LibraryManager.library, {
     saveHighScore: (score) => localStorage.setItem('cc_hi', score),
     loadHighScore: () => parseInt(localStorage.getItem('cc_hi') || '0'),
   });
   ```

6. **README.md** — build instructions, dependency list, how to run locally.

### Verification
- `dist/` folder contains only `index.html`, `card-capture.wasm`, `card-capture.data`
- Loads correctly from `python3 -m http.server 8080`
- High score persists across page refreshes
- Looks correct on both desktop and mobile viewport

---

## Build Commands Reference

```bash
# Install dependencies
# 1. Install Zig 0.13.0: https://ziglang.org/download/
# 2. Install Emscripten: https://emscripten.org/docs/getting_started/downloads.html
#    source emsdk/emsdk_env.sh

# Run locally (native, fast iteration)
zig build run

# Run tests
zig test src/rules.zig
zig test src/card.zig

# Build for web
zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseFast

# Serve locally
cd dist && python3 -m http.server 8080
# Open http://localhost:8080

# Optimize WASM (requires wasm-opt from binaryen)
wasm-opt dist/card-capture.wasm -O3 -o dist/card-capture.wasm
```

---

## Dependencies & Versions (Pin These)

| Tool | Version | Source |
|---|---|---|
| Zig | `0.13.0` | ziglang.org/download |
| Raylib | `5.0.0` | github.com/raysan5/raylib |
| raylib-zig | pin to commit matching Raylib 5.0 | github.com/Not-Nik/raylib-zig |
| Emscripten | `3.1.61` | emscripten.org |
| wasm-opt (optional) | latest | github.com/WebAssembly/binaryen |

---

## Coding Conventions for the Agent

- All allocations use an explicit `std.mem.Allocator` passed as parameter — no global allocator
- No `std.heap.page_allocator` in hot paths; use a fixed buffer allocator for animation queue
- Raylib calls only in `main.zig`, `ui.zig`, `animation.zig`, and `audio.zig` — game logic in `game.zig`, `rules.zig`, `card.zig`, `tutorial.zig` must be pure Zig with no Raylib dependency
- All magic numbers in `ui.zig` as `pub const`
- Error union returns for file I/O; `unreachable` only for provably impossible branches
- Use `@Vector` for any SIMD-amenable math (tween batching)
- No heap allocation after game init — pre-allocate all animation slots at startup

---

## Acceptance Criteria

The project is complete when:

- [ ] `zig build run` launches a native window and plays a full game
- [ ] `zig build -Dtarget=wasm32-emscripten` produces a working `dist/` bundle
- [ ] Tutorial mode completes without error and teaches all core mechanics
- [ ] All 7 animation types are implemented and play at 60fps
- [ ] Audio plays correctly in-browser (respecting autoplay policy)
- [ ] High score persists via localStorage
- [ ] All unit tests pass
- [ ] WASM binary is under 2MB after `wasm-opt`
- [ ] Game is winnable (deck can be fully exhausted)