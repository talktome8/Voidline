-- src/powerups/base.lua
local PowerUp = {}
PowerUp.__index = PowerUp

function PowerUp:new(x, y, duration)
    local obj = setmetatable({}, self)
    obj.x = x
    obj.y = y
    obj.duration = duration or 5
    obj.collected = false
    return obj
end

function PowerUp:apply(player)
    -- To be overridden by subclasses
end

function PowerUp:update(dt, player)
    -- Optional: for animated powerups
end

function PowerUp:draw(grid)
    -- Default: draw a simple circle
    local cellSize = grid.cellSize or 32
    love.graphics.setColor(1, 1, 0, 0.8)
    love.graphics.circle('fill', (self.x-0.5)*cellSize, (self.y-0.5)*cellSize, cellSize*0.3)
    love.graphics.setColor(1,1,1)
end

return PowerUp
