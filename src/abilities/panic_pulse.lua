-- Panic Pulse Ability: Pushes enemies away and provides temporary immunity
local PanicPulse = {}

PanicPulse.isActive = false
PanicPulse.cooldown = 25.0  -- 25 second cooldown
PanicPulse.currentCooldown = 0.0
PanicPulse.effectDuration = 2.0  -- 2 seconds of effect
PanicPulse.currentEffect = 0.0
PanicPulse.pushRadius = 6  -- Push enemies within 6 cells
PanicPulse.immunityDuration = 1.5  -- 1.5 seconds of immunity

function PanicPulse:load()
    print("Panic Pulse ability loaded")
end

function PanicPulse:update(dt)
    -- Update cooldown
    if self.currentCooldown > 0 then
        self.currentCooldown = self.currentCooldown - dt
    end
    
    -- Update effect duration
    if self.currentEffect > 0 then
        self.currentEffect = self.currentEffect - dt
        if self.currentEffect <= 0 then
            self.isActive = false
        end
    end
end

function PanicPulse:canActivate()
    return self.currentCooldown <= 0 and not self.isActive
end

function PanicPulse:activate(player, enemies, grid)
    if not self:canActivate() then
        return false
    end
    
    print("🚨 PANIC PULSE ACTIVATED!")
    
    self.isActive = true
    self.currentCooldown = self.cooldown
    self.currentEffect = self.effectDuration
    
    -- Push enemies away from player
    local pushedCount = 0
    for _, enemy in ipairs(enemies) do
        local distance = math.abs(enemy.i - player.i) + math.abs(enemy.j - player.j)
        if distance <= self.pushRadius then
            -- Calculate push direction
            local pushDirI = enemy.i - player.i
            local pushDirJ = enemy.j - player.j
            
            -- Normalize and amplify
            if pushDirI ~= 0 then pushDirI = pushDirI > 0 and 3 or -3 end
            if pushDirJ ~= 0 then pushDirJ = pushDirJ > 0 and 3 or -3 end
            
            -- Find new position
            local newI = math.max(1, math.min(grid.width, enemy.i + pushDirI))
            local newJ = math.max(1, math.min(grid.height, enemy.j + pushDirJ))
            
            -- Only push if new position is not claimed
            if not grid:isClaimed(newI, newJ) then
                enemy.i = newI
                enemy.j = newJ
                pushedCount = pushedCount + 1
            end
            
            -- Stun enemy briefly
            enemy.moveTimer = (enemy.moveTimer or 0) + 1.5
        end
    end
    
    -- Grant player temporary immunity
    player.panicPulseImmunity = self.immunityDuration
    
    print("Pushed", pushedCount, "enemies away!")
    return true
end

function PanicPulse:isPlayerImmune(player)
    return (player.panicPulseImmunity or 0) > 0
end

function PanicPulse:draw()
    if not self.isActive then return end
    
    -- Draw pulse effect around player
    local player = _G.Player or require('src.player')
    local grid = _G.Grid or require('src.grid')
    
    if player and grid then
        local px, py = grid:getNodePixelPosition(player.i, player.j)
        local radius = self.pushRadius * grid.cellSize
        local alpha = math.sin(love.timer.getTime() * 8) * 0.3 + 0.5
        
        -- Pulse rings
        love.graphics.setColor(1, 0.8, 0.2, alpha * 0.3)
        love.graphics.circle('line', px, py, radius)
        love.graphics.setColor(1, 1, 0.4, alpha * 0.2)
        love.graphics.circle('line', px, py, radius * 0.7)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function PanicPulse:drawUI(x, y)
    local available = self:canActivate()
    local color = available and {0.2, 1.0, 0.2} or {0.5, 0.5, 0.5}
    
    love.graphics.setColor(color)
    love.graphics.rectangle('fill', x, y, 120, 25, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('line', x, y, 120, 25, 5, 5)
    
    local text = available and "PANIC PULSE (P)" or string.format("Cooldown: %.1fs", self.currentCooldown)
    love.graphics.printf(text, x + 5, y + 6, 110, 'center')
end

return PanicPulse
