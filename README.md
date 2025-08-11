# Voidline – Development README

## 🔧 Project Summary

**Voidline** is a modular, scalable Love2D game that combines fast-paced territory capture with precision shape-drawing mechanics. Players must capture territory by drawing loops while simultaneously attempting to replicate target shapes shown in a mini-map. The game features dynamic enemy AI, progressive difficulty, and a comprehensive scoring system that rewards both territorial control and artistic accuracy.

### 🎯 **Core Gameplay Mechanics:**

## ✨ **Recent Updates**

What's new (highlights):
- Playfield clamps to the left grid only; right-side UI pane is reserved and safe.
- Dynamic grid sizing with smaller cells for a larger-feeling map. Stroke widths scale with cellSize.
- Single source of truth for target shape. Stars increment only for drawing the exact target with required accuracy.
- Dual objective to advance: required territory percent AND required shape accuracy for the target shape.
- Border safety: no idle deaths on the outer border; finish-on-safe enforcement for closures.
- Robust area closure and flood fill with in-bounds guards.
- Right-side Shape Panel replaces on-field text; shows target, stars, accuracy, and stats.
- Enemy difficulty scaling per level; boss spawns every 5th level and awards +1 life when captured in a closure.
- Captured enemies grant score bonus; enemies are relocated away from claimed areas.
- Basic touch steering for mobile: drag/hold to guide movement along the dominant axis.

## 🧱 Structure Overview
 love .

On Windows, you can also use the provided tasks or the batch files.
|-- main.lua
|-- conf.lua
- WASD / Arrow keys to move
- Touch: hold on the playfield to steer toward the touch (experimental)
- ESC to return to menu
|-- .vscode/
| |-- tasks.json
Close loops to claim territory. Complete the target shape with sufficient accuracy to earn stars. Advance when both objectives are met:
- Territory: meets level’s required percent (starts ~75%, scales up to 85%).
- Shape: draw the current level’s target with required accuracy (starts ~80%, scales up to 95%).

Every 5th level introduces a boss enemy. Capturing a boss inside a closure grants +1 life.
| |-- images/
| |-- sounds/
| |-- requireAll.lua
| |-- game.lua
| | |-- init.lua
| | |-- base.lua
| | |-- chaser.lua
| | |-- reclaimer.lua
| |-- characters/
| | |-- init.lua
| | |-- architect.lua
| | |-- trickster.lua
| |-- realms/
| | |-- init.lua
| | |-- void_hatchery.lua
| | |-- echo_lab.lua
| |-- abilities/
| | |-- init.lua
| | |-- panic_pulse.lua
| | |-- zone_mirror.lua
| |-- ui/
| | |-- init.lua
| | |-- menu.lua
| | |-- endrun.lua
| | |-- select_character.lua
| | |-- select_realm.lua
| |-- utils/
| | |-- init.lua
| | |-- math.lua
| | |-- debug.lua
| | |-- fileio.lua
| |-- systems/
| | |-- shape_templates.lua
| | |-- draw_path_system.lua
| | |-- shape_matcher.lua
| | |-- shape_score.lua
|-- shaders/

markdown
Copy
Edit


## 📦 Module Responsibilities

* `main.lua` – Launch entry point, loads core dependencies, prints "Voidline initialized".
* `conf.lua` – Configures window, framerate, vsync, title.
* `src/init.lua` – Loads all dynamic modules (characters, realms, abilities, enemies).
* `src/requireAll.lua` – Utility for requiring all Lua files in a directory.
* `game.lua` – Central state machine, main game loop, and shape-drawing integration.
* `player.lua` – WASD/arrow key input, movement, trail creation, and hitbox logic.
* `grid.lua` – Grid management, loop closure, zone ownership, visual rendering.
* `enemy/` – All enemy types and movement logic that interfere with shape drawing.
* `characters/` – Passive traits and stat tables per character.
* `realms/` – Special rulesets per map segment.
* `abilities/` – Time-limited powers usable in runs.
* `ui/` – Menu states, selection screens, overlays, stats display.
* `utils/` – Helper functions (math, debug, file IO).
* `systems/` – **Shape drawing mechanics:**
  * `shape_templates.lua` – Predefined target shapes for each level
  * `draw_path_system.lua` – Player path tracking and recording
  * `shape_matcher.lua` – Algorithms for comparing drawn vs target shapes
  * `shape_score.lua` – Scoring system with accuracy and time bonuses
  * `shape_feedback.lua` – **NEW**: Visual feedback with color changes and stars
* `shaders/` – Visual FX (glow, flicker, darkness, etc).

## 📚 Setup Guide

1. Make sure [Love2D](https://love2d.org/) is installed.
2. Clone the repo and open the root folder in VS Code.
3. Install these VS Code extensions:
   * Lua Language Server  
   * Love2D Support  
   * Path Intellisense  
   * Bracket Pair Colorizer 2 (optional)  
4. Run the project using Love2D launcher or VS Code task (see `.vscode/tasks.json`).

## 📌 Development Conventions

* Each module uses `:load`, `:update(dt)`, `:draw()` functions.
* Files should avoid cross-dependencies: use messaging or loader systems.
* All characters, realms, abilities, and enemies are loaded dynamically via `requireAll` and `init.lua` files.
* HUMP.gamestate is used for menu/state transitions.
* Use debug overlay toggles for FPS, shape matching state, and zone state.

## ✅ MVP Checklist

* [x] Project skeleton with all folders and files  
* [x] Dynamic loader system for modules  
* [x] HUMP.gamestate integrated  
* [x] VS Code task for Love2D  
* [x] Basic main.lua prints "Voidline initialized"  
* [x] Implement core gameplay logic  
* [x] Add first character, realm, enemy, and ability  
* [x] Implement grid and zone closing logic  
* [x] Add shape-drawing mechanic with score system  
* [x] Add time-based bonus/penalty mechanic  
* [x] Add UI screens (menu, selection, endrun)  
* [x] Add global highscore leaderboard and local score memory  

## 📂 Resources

* Font: Inter or IBM Plex Mono (free, clean UI fonts)
* Sound: Kenney SFX or custom synth loop kits
* Music: Optional, adaptive layers can enhance depth

## 💡 Commercial & Polish Recommendations

- Focus on a polished single-player experience.
- Target audience includes both younger players (spatial logic) and adults (light mental challenge).
- Invest in smooth, modern UI/UX and visual polish.
- Include visual shape indicators, score summaries, and drawing feedback.
- Create a free demo version, and offer a full paid game with:  
  - 50 handcrafted missions  
  - Variable difficulty  
  - Unlockable characters and abilities  
- Add Steam achievements and a persistent local & global leaderboard.
- Prepare a trailer and screenshots for the store page.
- Focus on visual clarity, snappy controls, and satisfying completion feedback.

## 🤝 Contribution

Follow the TODO file for phase breakdown. Branches by feature/module.

Open issues if structure, loading, or logic fail during integration.

---

Let the code flow. Close the void.
