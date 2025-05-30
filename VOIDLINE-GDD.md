**Voidline**
*Game Design Document – Full Functional Overview*

---

## 🎮 Game Overview

**Voidline** is a fast-paced, single-player arcade strategy game built on the concept of territory capture ("area closure") within dynamic stages. The game blends high-tempo movement, calculated risks, and strategic diversity using unique characters, unlockable stages, and adaptive challenges.

Each run lasts 5–10 minutes and offers a distinct experience due to different character traits, stage rules, enemy behaviors, and temporary abilities. Voidline is designed to be endlessly replayable through layered progression and evolving challenges.

---

## ⚖️ Core Gameplay Loop

1. **Select Character** – each with unique passive abilities.
2. **Enter the Map** – consisting of branching paths between themed stages ("Realms").
3. **Close Zones** by drawing enclosed paths while avoiding enemy interruptions.
4. **Survive Challenges** including dynamic enemies, stage hazards, and boss encounters.
5. **Unlock Progress** – through skill-based milestones (new characters, realms, or achievements).
6. **Start Again** – no permanent upgrades, each run is standalone with increasing options.

---

## 💡 Design Principles

* Modular, scalable code structure (each system in its own file).
* Emphasis on gameplay variety and mechanical clarity.
* No permanent power creep; the interest comes from learning, discovery, and adaptability.
* Use of dynamic loading to load content from directories (e.g., `src/characters`, `src/realms`).
* Clear use of gamestate management (recommended: HUMP.gamestate).

---

## 🔁 Gameplay Mechanics – Clarified

### Zone Closure Logic:

* The player can only close a zone by starting from an existing captured border and returning to it.
* If the player’s trail creates a closed loop, the enclosed space is validated using flood-fill logic.
* The enclosed area is claimed **only if no enemy is inside** it during closure.
* The player is vulnerable while drawing a trail – **direct enemy contact with the trail results in immediate death**.

### Closure Rewards:

* Claimed space increases a total captured percentage.
* Closing a larger zone yields a **scoring multiplier**.
* When the player captures \~75% of the total grid, the stage is completed.
* Captured zones become **inaccessible to enemies** (except for special boss behavior).

### Player Death:

* Touching an enemy or having the trail interrupted causes **instant game over**.
* Temporary abilities may prevent death (e.g., brief invulnerability).
* No lives or retries – the run ends.

---

## 🔄 Player Mechanics

* **Movement**: Grid-based directional control.
* **Zone Closure**: Drawing a complete loop converts enclosed space into secured territory.
* **Trail Vulnerability**: Player is vulnerable while extending a line.
* **Passive Traits**: Defined by the chosen character.
* **Temporary Active Abilities**: Occasionally granted, expire at boss encounters or between stages.

---

## 🏛️ World Structure: Realms

Each run consists of several stages chosen from a map of branching "Realms". Each Realm modifies core mechanics with its own visual style and rule twist.

### Sample Realms:

| Realm         | Unique Rule                                          | Visual Theme                 |
| ------------- | ---------------------------------------------------- | ---------------------------- |
| Void Hatchery | Closed zones split randomly                          | Purple void egg sacs         |
| Pulse Mines   | Timed shockwaves across the grid                     | Industrial tech aesthetic    |
| Echo Lab      | Zones close, re-open briefly, then reclose           | Sterile lab with echo pulses |
| Dark Arena    | Limited visibility, flashlight radius only           | Complete darkness            |
| Light Spiral  | Movement creates visible trails that attract enemies | Luminous vortex              |
| ??? Zone      | Rules change every 15 seconds                        | Glitchy, shifting visuals    |

Each Realm is unlocked via player achievements or hidden triggers.

Stage difficulty scales with Realm order. After several Realms, a boss appears.

---

## 🚪 Character System

Characters offer core strategic diversity. Each has:

* **Name + Description**
* **2–3 Passive Abilities** (e.g., invulnerable trail, faster zone capture, camouflage)
* **Base Stats**:

  * Movement speed (1.0–3.0)
  * Trail decay duration (in seconds)
  * View range (number of tiles visible in darkness Realms)
  * Zone closure multiplier

### Example Characters:

| Name          | Description             | Passive Abilities                                        | Stats               |
| ------------- | ----------------------- | -------------------------------------------------------- | ------------------- |
| The Architect | Methodical, precise     | Larger zone bonus, trail stable for longer               | Speed: 2.0, View: 6 |
| The Trickster | Agile and unpredictable | Enemies react slower, mini-stun when reversing direction | Speed: 2.8, View: 4 |
| The Echo      | Dimensional copy        | Trail pulses outward to stun enemies                     | Speed: 2.2, View: 5 |

Characters are unlocked through performance-based challenges and certain Realm completions.

---

## 💥 Temporary Abilities

Granted mid-run. They:

* Have cooldowns or time-based duration.
* Expire after boss battles.
* Encourage moment-to-moment adaptation.

### Examples:

* **Phase Shift**: Move through enemies for 2 seconds.
* **Zone Mirror**: Duplicate score of the next enclosed area.
* **Panic Pulse**: Shockwave repels enemies around the player.

---

## 👾 Enemies

Enemies vary per Realm and scale over time:

* **Chaser**: Directly follows player.
* **Reclaimer**: Reopens previously closed zones.
* **Infester**: Infects player-owned zones from within.
* **Jammer**: Blurs visuals and inverts controls.

Each has specific logic and positioning strategy. Bosses are upgraded versions with map-wide effects.

Enemy interaction:

* Contact with trail = death.
* Enemies cannot enter captured zones, unless they are bosses or special types.

---

## 🌟 Boss Design

Bosses appear after every few Realms and change rules globally.

### Examples:

* **The Reclaimer**: Opens zones in real time; you must outplay it spatially.
* **The Dusk**: Total darkness. Only light comes from captured zones.
* **The Glitch**: Changes movement direction, disables UI, randomizes rules.
* **The Spiral**: Rotates map or shifts controls periodically.
* **The Rival**: Competes by opening zones you close. Slower than the player but relentless.

---

## 📈 End of Run Stats

After each run, a detailed breakdown appears:

* Total grid captured (% and area)
* Enemies defeated
* Zones closed
* Bosses reached / defeated
* Death cause
* Abilities used
* Comparison to last 5 runs
* Global percentile (if leaderboards are enabled later)

---

## 📆 Progression & Replayability

* **No permanent upgrades**.
* Progress comes from unlocking new characters, Realms, and passive visual effects.
* Meta-map reflects your choices and achievements.
* Special achievements unlock secret Realms or characters.
* Daily/Weekly challenge mode (rotating conditions and leaderboard).

---

## 🎨 Visual & Audio Design

* Visual theme inspired by Balatro: sharp contrasts, glow effects, shifting visuals.
* Sound design reinforces state: stress during trail, relief during closure, stingers for boss proximity.
* Music shifts between stages and reacts to intensity.
* Visual feedback increases with performance: longer trails, world effects.

---

## 🚀 Technical Design (Love2D)

### Directory Structure

```
/voidline
|-- main.lua
|-- conf.lua
|-- README.md
|-- TODO.md
|-- assets/
|   |-- images/
|   |-- sounds/
|   |-- fonts/
|-- src/
|   |-- game.lua
|   |-- player.lua
|   |-- grid.lua
|   |-- enemy/
|   |   |-- base.lua
|   |   |-- chaser.lua
|   |   |-- reclaimer.lua
|-- characters/
|   |-- architect.lua
|   |-- trickster.lua
|-- realms/
|   |-- void_hatchery.lua
|   |-- echo_lab.lua
|-- abilities/
|   |-- panic_pulse.lua
|   |-- zone_mirror.lua
|-- ui/
|-- utils/
|   |-- requireAll.lua
|-- shaders/
```

### Engine Behavior

* `main.lua`: Initializes game, sets global variables.
* `conf.lua`: Configures window, settings.
* `game.lua`: Core game loop and state manager.
* `grid.lua`: Manages zone capture, loop detection, visual effects.
* `player.lua`: Handles input, movement, and trail logic.
* `enemy/*.lua`: Contains logic for enemy behavior and attack patterns.
* `realms/*.lua`: Define stage-specific rules and assets.
* `characters/*.lua`: Passive abilities and stats per character.
* `abilities/*.lua`: Trigger, update, and draw logic for actives.
* `ui/`: Manages overlays, character selection, menus.
* `utils/`: Common math helpers, logging, data parsing.
* `shaders/`: GLSL files for glow, distortion, darkness, etc.

All elements are decoupled for easy expansion.

---

## 🔍 Final Notes

Voidline is designed to be strategic, reactive, and atmospheric. Players should feel both vulnerable and powerful at every moment. The lack of permanent upgrades emphasizes mastery and adaptation over grind.

Every piece of content—enemy, realm, character—is modular and easy to extend. Every decision—narrative, visual, mechanical—reinforces the loop of closing zones to keep the void at bay.

Let the game begin.
