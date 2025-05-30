local EnemyBase = {}
EnemyBase.__index = EnemyBase

function EnemyBase:new(i, j)
    local e = setmetatable({}, self)
    e.i = i
    e.j = j
    e.type = 'base'
    return e
end

function EnemyBase:load(grid)
    -- Override in child
end

function EnemyBase:update(dt, grid, player)
    -- Override in child
end

function EnemyBase:draw(grid)
    love.graphics.setColor(0.8, 0.2, 0.2)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    love.graphics.circle('fill', x, y, grid.cellSize*0.3)
    love.graphics.setColor(1,1,1)
end

return EnemyBase
