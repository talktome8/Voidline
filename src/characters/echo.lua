-- src/characters/echo.lua
-- Defines the Echo character: passives, stats, ability stubs, and per-stage modifier system.
-- Each character can define characterStageModifier(stage, player, grid) to add unique challenges or bonuses in specific realms/stages.

local Echo = {}

Echo.name = "The Echo"
Echo.description = "Dimensional copy. Trail pulses outward to stun enemies."
Echo.color = {0.7, 0.4, 1}
Echo.trailColor = {0.9, 0.7, 1}
Echo.speed = 2.2
Echo.trailLength = 18
Echo.passives = {
    "Passive: Trail pulses outward to stun enemies.",
    "Medium speed, balanced stats."
}

function Echo:applyPassive(player)
    -- Passive effects applied to player (e.g., trail pulse)
    -- Trail pulse stuns enemies (handled in player or enemy logic)
    player.trailPulseStun = true
    -- Balanced speed (already set in base stats)
end

function Echo:activateAbility(player, grid)
    -- Trail pulse logic handled in player.lua
end

function Echo:characterStageModifier(stage, player, grid)
    -- Example: In "Pulse Mines", Echo's pulse stuns for longer
    if stage and stage.name and stage.name:find("Pulse Mines") then
        player.pulseStunBonus = true
    end
    -- Add more unique stage/realm effects here
end

return Echo
