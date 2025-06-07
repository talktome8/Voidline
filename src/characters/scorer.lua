-- src/characters/scorer.lua
-- Defines the Scorer character: passives, stats, ability stubs, and per-stage modifier system.
-- Each character can define characterStageModifier(stage, player, grid) to add unique challenges or bonuses in specific realms/stages.

local Scorer = {}
Scorer.name = "Scorer"
Scorer.description = "Gets double points for closing large areas."
Scorer.color = {1, 1, 0.3}
Scorer.trailColor = {1, 1, 0.5}
Scorer.speed = 2.0
Scorer.trailLength = 16
Scorer.passives = {
    "Passive: Double score for large zone closures.",
    "Normal speed, normal trail."
}

function Scorer:applyPassive(player)
    -- Double score for large zone closures
    player.largeZoneScoreMultiplier = 2
end

function Scorer:activateAbility(player, grid)
    -- No active ability
end

function Scorer:characterStageModifier(stage, player, grid)
    -- In "Large Arena", Scorer gets triple points for huge closures
    if stage and stage.name and stage.name:find("Large Arena") then
        player.tripleScoreBonus = true
    end
    -- Add more unique stage/realm effects here
end

return Scorer
