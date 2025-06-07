Voidline – TODO List (Phase Breakdown)

🟩 Phase 1: Foundation Setup
- [x] Create all folders and base files (src/, assets/, shaders/, etc)
- [x] Add empty Lua modules with load/update/draw
- [x] Implement requireAll dynamic loader
- [x] Add init.lua to all module folders
- [x] Integrate HUMP.gamestate
- [x] Add VS Code tasks.json for Love2D
- [x] Basic main.lua prints "Voidline initialized"


🟦 Phase 2: Core Modules (MVP)
- [ ] Implement player movement and trail
- [ ] Implement grid and zone closure logic
- [ ] Implement basic enemy (chaser)
- [ ] Implement first character (architect)
- [ ] Implement first realm (void_hatchery)
- [ ] Implement first ability (panic_pulse)
- [ ] Improve island ("אי"/green area) behavior: islands should act as captured territory, and closing a zone with an island should only fill when returning to the border or island
- [ ] Improve zone closure logic: only close zones if the player returns to the border or an island, not just by drawing a line
- [ ] Improve fuse/danger logic: fuse should disappear and player should be in danger only when appropriate


🟦 Phase 2.5: Essential Playability
- [x] Add in-game tutorial or how-to-play screen
- [ ] Add sound effects (zone close, death, ability, boss)
- [ ] Add background music (stage-dependent if possible)
- [ ] When an enemy is captured inside a closed zone, turn it into a powerup (reward the player instead of causing game over)


🟨 Phase 3: Game Flow & UI
- [ ] Character selection screen
- [ ] Realm selection mockup
- [ ] End-of-run screen (win/lose)
- [x] Menu and overlays
- [ ] Separate powerups and enemies more clearly (visuals, logic, and interactions)


🟨 Phase 3.5: Player Motivation & Feedback
- [x] Add achievements/challenges (e.g. close 90%, defeat boss, finish with each character)
- [x] Add more powerups and ability types
- [x] Add more enemy patterns and unique boss mechanics
- [x] Add new enemy types: Splitter (splits when trapped), Phaser (can phase through walls)
- [x] Add advanced stages with new enemy combinations and chaos mode
- [ ] Add new enemy types: enemies that erase closed territory, enemies that duplicate themselves


🟥 Phase 4: Polish & Debug Tools
- [x] Debug overlay (FPS, zone state)
- [x] Visual polish, shaders, and effects
- [x] Sound and music integration
- [x] Add visual feedback for ability use and cooldown
- [x] Add smooth transitions between stages
- [x] Add detailed end-of-run stats (zones closed, abilities used, etc.)
- [x] Add quick restart option


🟪 Phase 5: Extended Content & Testing
- [ ] Add more characters, realms, enemies, abilities
- [ ] Playtesting and balancing
- [ ] Achievements and meta-map
- [ ] Add meta-progression or unlockable cosmetics (optional)


# Commercial Potential & Recommendations
- [x] Focus on single-player only (no multiplayer)
- [x] Invest in modern, polished UI/UX and beautiful animations
- [x] Add adaptive music and high-quality sound effects
- [x] Add more achievements, unlocks, and meta-progression
- [x] Provide a free demo, then offer a paid full version
- [x] Prepare a trailer and screenshots for store pages
- [x] Playtest for difficulty balance and fun factor


Track changes and milestones with git commits tagged by phase.
Mark completed tasks and sync with README checklist regularly.

Let the void be closed, line by line.