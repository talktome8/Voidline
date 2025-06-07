--[[
Architect Character Module
Defines the "Architect" character, including passive abilities, stats, and active ability logic.
This file is loaded dynamically by the character loader.

Abilities:
- Passive: Area closure is easier. Trail persists if you stop. Large zone bonus.
- Active: None (by default)

Functions:
- Architect:applyPassive(player): Applies passive effects to the player.
- Architect:activateAbility(player, grid): (Stub for future active ability)
- Architect:characterStageModifier(stage, player, grid): Optional per-stage logic.
]]

local Architect = {}

Architect.name = "Architect"
Architect.description = "Area closure is easier. Trail persists if you stop. Large zone bonus."
Architect.color = {0.1, 0.5, 1} -- blue
Architect.trailColor = {0.2, 0.7, 1} -- yellow

Architect.speed = 1.7 -- Slightly slower, as "בונה לאט"
Architect.trailLength = 20 -- Standard, can be adjusted if needed

-- New properties for passives
Architect.trailPersistDuration = 1.5 -- seconds, "קו ה־trail לא נעלם במשך 2 שניות"
Architect.largeZoneBonusMultiplier = 2 -- "שטחים גדולים מקבלים ניקוד כפול"
Architect.loopClosureBonusPercent = 0.01 -- 1% bonus, "תוספת קטנה לאחוז הסגירה"
Architect.largeZoneThreshold = 50 -- Example threshold for 'large zone', in cells
Architect.freezeDuration = 1 -- seconds, for enemy freeze passive
Architect.fuseDuration = 5 -- פיוז רגיל

Architect.passives = {
    "Passive: Trail persists if you stop.",
    "Large zone bonus.",
    "Area closure is easier."
}

---
-- Returns a string describing all passive abilities.
function Architect:getSkillDescription()
    return table.concat(self.passives, "\n")
end

---
-- Loads any state for the character (stub).
function Architect:load()
    -- any specific load-time setup for Architect
end

---
-- Updates any state for the character (stub).
function Architect:update(dt)
    -- any specific update logic for Architect (e.g., managing internal timers for abilities)
end

---
-- Draws any special visuals for the character (stub).
function Architect:draw()
    -- any specific drawing for Architect (e.g., visual cues for abilities)
end

---
-- Applies passive effects to the player.
-- @param player The player object
function Architect:applyPassive(player)
    -- Trail persists if you stop
    player.architectTrailPersistTimer = 0
    player.architectLastTrailCells = {}
end

---
-- (Stub) Activates the character's active ability.
function Architect:activateAbility(player, grid)
    -- No active ability for Architect by default
end

---
-- (Optional) Modifies stage/realm for this character.
function Architect:characterStageModifier(stage, player, grid)
    -- No special logic for Architect
end

return Architect
