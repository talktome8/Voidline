-- src/characters/sprinter.lua
-- Defines the Sprinter character: passives, stats, ability stubs, and per-stage modifier system.
-- Each character can define characterStageModifier(stage, player, grid) to add unique challenges or bonuses in specific realms/stages.

local Sprinter = {}
Sprinter.name = "Sprinter"
Sprinter.description = "Moves very fast, but trail is fragile."
Sprinter.color = {1, 0.5, 0.2}
Sprinter.trailColor = {1, 0.7, 0.2}
Sprinter.speed = 3.2
Sprinter.trailLength = 14
Sprinter.passives = {
    "Passive: +50% movement speed.",
    "Trail disappears quickly if not closed."
}

function Sprinter:applyPassive(player)
    -- +50% movement speed
    player.speedMultiplier = 1.5
    -- Trail disappears quickly if not closed
    player.trailFragility = 2
    -- Dash ability handled in player logic
end

function Sprinter:activateAbility(player, grid)
    -- Dash logic handled in player.lua
end

function Sprinter:characterStageModifier(stage, player, grid)
    -- In "Speed Zones", Sprinter gets double dash duration
    if stage and stage.name and stage.name:find("Speed Zones") then
        player.dashDurationBonus = true
    end
    -- Add more unique stage/realm effects here
end

return Sprinter
