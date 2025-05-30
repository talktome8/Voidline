# Voidline – Development README

## 🔧 Project Summary

**Voidline** is a modular, scalable Love2D game based on fast-paced area closure and reactive arcade strategy. This project prioritizes replayability, responsive gameplay, and clean modular code.

---

## 🧱 Structure Overview

```
/voidline
|-- main.lua
|-- conf.lua
|-- README.md
|-- TODO.md
|-- .vscode/
|   |-- tasks.json
|-- assets/
|   |-- images/
|   |-- sounds/
|   |-- fonts/
|-- src/
|   |-- init.lua
|   |-- requireAll.lua
|   |-- game.lua
|   |-- player.lua
|   |-- grid.lua
|   |-- enemy/
|   |   |-- init.lua
|   |   |-- base.lua
|   |   |-- chaser.lua
|   |   |-- reclaimer.lua
|   |-- characters/
|   |   |-- init.lua
|   |   |-- architect.lua
|   |   |-- trickster.lua
|   |-- realms/
|   |   |-- init.lua
|   |   |-- void_hatchery.lua
|   |   |-- echo_lab.lua
|   |-- abilities/
|   |   |-- init.lua
|   |   |-- panic_pulse.lua
|   |   |-- zone_mirror.lua
|   |-- ui/
|   |   |-- init.lua
|   |   |-- menu.lua
|   |   |-- endrun.lua
|   |   |-- select_character.lua
|   |   |-- select_realm.lua
|   |-- utils/
|   |   |-- init.lua
|   |   |-- math.lua
|   |   |-- debug.lua
|   |   |-- fileio.lua
|-- shaders/
```

---

## 📦 Module Responsibilities

* `main.lua` – Launch entry point, loads core dependencies, prints "Voidline initialized".
* `conf.lua` – Configures window, framerate, vsync, title.
* `src/init.lua` – Loads all dynamic modules (characters, realms, abilities, enemies).
* `src/requireAll.lua` – Utility for requiring all Lua files in a directory.
* `game.lua` – Central state machine and main game loop.
* `player.lua` – Input, movement, trail creation, and hitbox logic.
* `grid.lua` – Grid management, loop closure, zone ownership.
* `enemy/` – All enemy types and movement logic.
* `characters/` – Passive traits and stat tables per character.
* `realms/` – Special rulesets per map segment.
* `abilities/` – Time-limited powers usable in runs.
* `ui/` – Menu states, selection screens, overlays.
* `utils/` – Helper functions (math, debug, file IO).
* `shaders/` – Visual FX (glow, flicker, darkness, etc).

---

## 📚 Setup Guide

1. Make sure [Love2D](https://love2d.org/) is installed.
2. Clone the repo and open the root folder in VS Code.
3. Install these VS Code extensions:

   * Lua Language Server
   * Love2D Support
   * Path Intellisense
   * Bracket Pair Colorizer 2 (optional)
4. Run the project using Love2D launcher or VS Code task (see `.vscode/tasks.json`).

---

## 📌 Development Conventions

* Each module uses `:load`, `:update(dt)`, `:draw()` functions.
* Files should avoid cross-dependencies: use messaging or loader systems.
* All characters, realms, abilities, and enemies are loaded dynamically via `requireAll` and `init.lua` files.
* HUMP.gamestate is used for menu/state transitions.
* Use debug overlay toggles for FPS and zone state.

---

## ✅ MVP Checklist

* [x] Project skeleton with all folders and files
* [x] Dynamic loader system for modules
* [x] HUMP.gamestate integrated
* [x] VS Code task for Love2D
* [x] Basic main.lua prints "Voidline initialized"
* [ ] Implement core gameplay logic
* [ ] Add first character, realm, enemy, and ability
* [ ] Implement grid and zone closing logic
* [ ] Add UI screens (menu, selection, endrun)

---

## 📂 Resources

* Font: Inter or IBM Plex Mono (free, clean UI fonts)
* Sound: Kenney SFX or custom synth loop kits
* Music: Optional, adaptive layers can enhance depth

---

## 🤝 Contribution

Follow the TODO file for phase breakdown. Branches by feature/module.

Open issues if structure, loading, or logic fail during integration.

---

Let the code flow. Close the void.
