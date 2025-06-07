-- src/characters/trickster.lua
-- Defines the Trickster character: passives, stats, and ability stubs.
-- Each character can define characterStageModifier(stage, player, grid) to add unique challenges or bonuses in specific realms/stages.

local Trickster = {}

Trickster.name = "Trickster"
Trickster.description = "Swaps with enemies, creates decoys to misdirect foes. Fastest movement."
Trickster.color = {1, 0.7, 0.2}
Trickster.trailColor = {1, 0.9, 0.5}
Trickster.speed = 2.8
Trickster.trailLength = 16

Trickster.decoySpeedMultiplier = 1.25
Trickster.decoyDuration = 2.5
Trickster.decoyCooldown = 8

Trickster.passives = {
    "Passive: Enemies react slower, mini-stun when reversing direction.",
    "Active: Decoy Swap (SPACE) - swap with a decoy, 8s cooldown.",
    "Trail is less stable (disappears quickly if not closed)."
}

Trickster.activeAbilityName = "Decoy Swap"
Trickster.activeAbilityDesc = "Press SPACE to swap with a decoy. 8s cooldown."
Trickster.activeAbilityCooldown = 8

function Trickster:getSkillDescription()
    return table.concat(self.passives, "\n")
end

function Trickster:load()
end

function Trickster:update(dt)
end

function Trickster:draw()
end

function Trickster:applyPassive(player)
    -- Enemies react slower (could be implemented as a global enemy delay modifier)
    player.enemyReactionDelay = 0.2
    -- Mini-stun on direction change (handled in enemy logic)
    player.tricksterStunOnReverse = true
end

function Trickster:activateAbility(player, grid)
    -- Decoy Swap logic handled in player.lua
end

function Trickster:characterStageModifier(stage, player, grid)
    -- In "Echo Lab", Trickster faces more decoys
    if stage and stage.name and stage.name:find("Echo Lab") then
        player.extraDecoys = true
    end
    -- Add more unique stage/realm effects here
end

return Trickster
