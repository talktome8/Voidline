-- src/ui/ingame_hud.lua
-- Handles all in-game HUD overlays: ability bar, floating text, jammed tint, and other UI elements.

local IngameHUD = {}

---
-- Draws all in-game HUD overlays: ability bar, floating text, jammed tint, infected zones, and more.
-- @param game The game state object
-- @param player The player object
-- @param grid The grid object
-- @param powerups List of powerups
-- @param unlockMessage Optional unlock message to display
function IngameHUD:draw(game, player, grid, powerups, unlockMessage)
    -- Draw jammed screen tint
    if player.isJammed then
        love.graphics.setColor(0.7, 0.2, 1, 0.10)
        love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1,1,1)
    end

    -- Draw floating text for powerup pickup
    if player.lastPowerupText and player.lastPowerupTextTimer and player.lastPowerupTextTimer > 0 then
        love.graphics.setFont(love.graphics.newFont(18))
        love.graphics.setColor(0.2,0.9,1,0.85)
        love.graphics.printf(player.lastPowerupText, 0, love.graphics.getHeight()/2-40, love.graphics.getWidth(), 'center')
        love.graphics.setColor(1,1,1)
    end

    -- Draw ability bar (top left)
    local char = player.character
    if char and char.activeAbilityName then
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.setColor(0.13,0.13,0.18,0.85)
        love.graphics.rectangle('fill', 12, 12, 220, 40, 10, 10)
        love.graphics.setColor(1,1,1)
        love.graphics.setColor(0.8,0.9,1)
        love.graphics.print('Ability: '..char.activeAbilityName, 24, 24)
        if player.abilityCooldown then
            love.graphics.setColor(1,0.7,0.2)
            love.graphics.print('Cooldown: '..string.format('%.1f', player.abilityCooldown), 140, 24)
        end
        love.graphics.setColor(1,1,1)
    end

    -- Draw claimed/required/level (top center) unless minimal HUD is enabled
    if not (game and game.minimalHUD) then
        local percent = math.floor((grid:getClaimedPercent() or 0)*100)
        local req = math.floor(((grid.requiredClaimedPercent or 0)*100))
        local level = game.level or 1
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.setColor(0.13,0.13,0.18,0.85)
        love.graphics.rectangle('fill', love.graphics.getWidth()/2-90, 10, 180, 36, 8, 8)
        love.graphics.setColor(1,1,1)
        love.graphics.printf('Level '..level..'   Claimed: '..percent..'/'..req..'%', love.graphics.getWidth()/2-90, 18, 180, 'center')
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.setColor(1,1,1)
    end

    -- Draw unlock message if present
    if unlockMessage then
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.setColor(0.2, 0.8, 0.2, 0.85)
        love.graphics.printf(unlockMessage, 0, 70, love.graphics.getWidth(), 'center')
        love.graphics.setColor(1,1,1)
    end

    -- Optional infected zone indicator (hidden in minimal HUD)
    if not (game and game.minimalHUD) then
        local infectedCount = 0
        for i=1,grid.width do
            for j=1,grid.height do
                if grid.cells[i] and grid.cells[i][j] == 'infected' then
                    infectedCount = infectedCount + 1
                end
            end
        end
        if infectedCount > 0 then
            love.graphics.setFont(love.graphics.newFont(14))
            love.graphics.setColor(1,0.3,0.3,0.9)
            love.graphics.printf('Infected Zones: '..infectedCount, love.graphics.getWidth()/2-90, 50, 180, 'center')
            love.graphics.setColor(1,1,1)
        end
    end

    -- Draw ability bar for current character (if any active ability)
    if player and player.character and player.character.activateAbility then
        local abilityName = player.character.activeAbilityName or "Ability"
        local cooldown = player.abilityCooldown or 0
        local maxCooldown = player.character.activeAbilityCooldown or 8
        local ready = (cooldown <= 0)
        local barW, barH = 120, 18
        local x = love.graphics.getWidth()/2 - barW/2
        local y = love.graphics.getHeight() - 48
        love.graphics.setColor(0.18,0.18,0.22,0.85)
        love.graphics.rectangle('fill', x, y, barW, barH, 8, 8)
        love.graphics.setColor(ready and 0.2 or 1, ready and 1 or 0.2, 0.2, 1)
        local fillW = ready and barW or barW * (1 - cooldown/maxCooldown)
        love.graphics.rectangle('fill', x, y, fillW, barH, 8, 8)
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(love.graphics.newFont(13))
        love.graphics.printf(abilityName..(ready and " (Ready!)" or (" ("..math.ceil(cooldown).."s)")), x, y+2, barW, 'center')
    end

    -- Draw failed closure warning if present
    if player.failedClosureWarning and player.failedClosureWarning > 0 then
        love.graphics.setFont(love.graphics.newFont(22))
        love.graphics.setColor(1,0.2,0.2,math.min(1, player.failedClosureWarning))
        love.graphics.printf('Finish on safe area (border or claimed) to complete!', 0, love.graphics.getHeight()/2-60, love.graphics.getWidth(), 'center')
        love.graphics.setColor(1,1,1)
        player.failedClosureWarning = player.failedClosureWarning - (love.timer.getDelta() or 0.016)
        if player.failedClosureWarning < 0 then player.failedClosureWarning = 0 end
    end
end

return IngameHUD
