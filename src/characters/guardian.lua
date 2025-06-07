-- src/characters/guardian.lua
-- Defines the Guardian character: passives, stats, ability stubs, and per-stage modifier system.
-- Each character can define characterStageModifier(stage, player, grid) to add unique challenges or bonuses in specific realms/stages.

local Guardian = {}
Guardian.name = "Guardian"
Guardian.description = "פיוז איטי, יכולת לנטרל פיוז פעם אחת"
Guardian.speed = 1.3
Guardian.trailLength = 18
Guardian.color = {0.2, 0.7, 1}
Guardian.trailColor = {0.2, 0.9, 1}
Guardian.passives = {
    "Passive: Can defuse fuse once per run (press D)",
    "Slow fuse: 8 seconds to return to border.",
    "Immune to first GuardianBreaker attack.",
    "Trail is more stable (less likely to disappear)."
}

function Guardian:getSkillDescription()
    return table.concat(self.passives, "\n")
end

function Guardian:applyPassive(player)
    -- Can defuse fuse once per run
    player.fuseDefuseAvailable = true
    -- Slow fuse: 8 seconds
    player.fuseDuration = 8
    -- Immune to first GuardianBreaker attack
    player.immuneToGuardianBreaker = true
    -- Trail is more stable
    player.trailStability = 2
end

function Guardian:activateAbility(player, grid)
    -- Fuse defuse logic handled in player.lua
end

function Guardian:characterStageModifier(stage, player, grid)
    -- In "Pulse Mines", Guardian gets +2 seconds fuse time
    if stage and stage.name and stage.name:find("Pulse Mines") then
        player.fuseDuration = (player.fuseDuration or 8) + 2
    end
    -- Add more unique stage/realm effects here
end

return Guardian
