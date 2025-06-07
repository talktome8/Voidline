-- src/powerups/freeze.lua
local Freeze = {}
Freeze.name = "Freeze"
Freeze.description = "Freezes all enemies for 3 seconds."
Freeze.icon = nil -- (add icon path if needed)

function Freeze:activate(game, grid, player, enemies)
    for _, enemy in ipairs(enemies) do
        enemy._frozenTimer = 3
    end
    player.freezeActive = true
    player.freezeTimer = 3
end

function Freeze:update(dt, game, grid, player, enemies)
    for _, enemy in ipairs(enemies) do
        if enemy._frozenTimer and enemy._frozenTimer > 0 then
            enemy._frozenTimer = enemy._frozenTimer - dt
            if enemy._frozenTimer < 0 then enemy._frozenTimer = 0 end
        end
    end
    if player.freezeActive then
        player.freezeTimer = player.freezeTimer - dt
        if player.freezeTimer <= 0 then
            player.freezeActive = false
            player.freezeTimer = 0
        end
    end
end

function Freeze:isEnemyFrozen(enemy)
    return enemy._frozenTimer and enemy._frozenTimer > 0
end

return Freeze
