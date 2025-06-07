-- src/powerups/speed_boost.lua
-- Speed boost powerup: temporarily increases player speed. Implements apply(player) and draw(grid).

local PowerUp = require('src.powerups.base')
local SpeedBoost = setmetatable({}, {__index = PowerUp})
SpeedBoost.__index = SpeedBoost

function SpeedBoost:new(x, y, duration, boostAmount)
    local obj = PowerUp.new(self, x, y, duration or 5)
    obj.boostAmount = boostAmount or 1.5
    obj.type = "SpeedBoost"
    return obj
end

function SpeedBoost:apply(player)
    if not player or self.collected then return end
    player.speedBoostTimer = self.duration
    self.collected = true
end

function SpeedBoost:draw(grid)
    local cellSize = grid.cellSize or 32
    love.graphics.setColor(0.2, 0.9, 1, 0.85)
    love.graphics.circle('fill', (self.x-0.5)*cellSize, (self.y-0.5)*cellSize, cellSize*0.3)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print('S', (self.x-0.5)*cellSize-6, (self.y-0.5)*cellSize-8)
end

return SpeedBoost
