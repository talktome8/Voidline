local EnemyBase = require 'src.enemy.base'
local Reclaimer = setmetatable({}, {__index = EnemyBase})
Reclaimer.__index = Reclaimer

function Reclaimer:new(i, j, level)
    local e = EnemyBase.new(self, i, j)
    e.type = 'reclaimer'
    e.moveDelay = 1.2 -- always fair
    e.moveTimer = 0
    e.level = level or 1
    print('DEBUG: Reclaimer:new - level:', level, 'moveDelay:', e.moveDelay)
    return e
end

function Reclaimer:update(dt, grid, player)
    self.moveTimer = self.moveTimer - dt
    if self.moveTimer > 0 then return end
    self.moveTimer = self.moveDelay
    -- Always move only one cell per update, toward player or to reclaim
    local bestDist = math.huge
    local bestMove = {self.i, self.j}
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    for _, d in ipairs(dirs) do
        local ni, nj = self.i + d[1], self.j + d[2]
        if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
            local dist = math.abs(ni-player.i) + math.abs(nj-player.j)
            if dist < bestDist then
                bestDist = dist
                bestMove = {ni, nj}
            end
        end
    end
    self.i, self.j = bestMove[1], bestMove[2]
end

function Reclaimer:draw(grid)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    -- Unique: Reclaimer is a gold pentagon
    if self._justErased then
        love.graphics.setColor(1,0.7,0.2,1)
    else
        love.graphics.setColor(0.7,0.3,0.1,1)
    end
    local r = grid.cellSize*0.19
    local points = {}
    for i=0,4 do
        local angle = math.pi*2/5 * i - math.pi/2
        table.insert(points, x + r*math.cos(angle))
        table.insert(points, y + r*math.sin(angle))
    end
    love.graphics.polygon('fill', points)
    love.graphics.setColor(1,1,1)
end

return Reclaimer
