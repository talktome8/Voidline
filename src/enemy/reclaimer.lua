local EnemyBase = require 'src.enemy.base'
local Reclaimer = setmetatable({}, {__index = EnemyBase})
Reclaimer.__index = Reclaimer

function Reclaimer:new(i, j, level)
    local e = EnemyBase.new(self, i, j)
    e.type = 'reclaimer'
    level = level or 1
    e.moveDelay = math.max(0.45 - 0.05 * (level-1), 0.25) -- לא פחות מ-0.25
    e.moveTimer = 0
    e.level = level
    print('DEBUG: Reclaimer:new - level:', level, 'moveDelay:', e.moveDelay)
    return e
end

function Reclaimer:update(dt, grid, player)
    -- תנועה: קודם כל נסה למחוק אזור לא צבוע, אחרת רדוף אחרי השחקן
    local bestDist = math.huge
    local bestMove = {self.i, self.j}
    local foundEmpty = false
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    for _, d in ipairs(dirs) do
        local ni, nj = self.i + d[1], self.j + d[2]
        if grid:isInside(ni, nj) and grid.cells[ni][nj] == 'empty' then
            foundEmpty = true
            local dist = math.abs(ni-player.i) + math.abs(nj-player.j)
            if dist < bestDist then
                bestDist = dist
                bestMove = {ni, nj}
            end
        end
    end
    if foundEmpty then
        self.i, self.j = bestMove[1], bestMove[2]
        grid.cells[self.i][self.j] = 'empty' -- מוחק אזור
        self._justErased = true
    else
        -- רדוף אחרי השחקן
        bestDist = math.huge
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
        self._justErased = false
    end
end

function Reclaimer:draw(grid)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    if self._justErased then
        love.graphics.setColor(1,0.7,0.2,1)
    else
        love.graphics.setColor(0.7,0.3,0.1,1)
    end
    love.graphics.circle('fill', x, y, grid.cellSize*0.33)
    love.graphics.setColor(1,1,1)
end

return Reclaimer
