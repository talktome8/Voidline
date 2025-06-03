-- GuardianBreaker enemy: hunts Guardian, destroys fuse defuse ability if close
local EnemyBase = require('src.enemy.base')
local GuardianBreaker = setmetatable({}, {__index = EnemyBase})
GuardianBreaker.__index = GuardianBreaker

function GuardianBreaker:new(i, j)
    local self = setmetatable(EnemyBase:new(i, j), GuardianBreaker)
    self.color = {1, 0.2, 0.2}
    self.targetType = "Guardian"
    return self
end

function GuardianBreaker:update(dt, grid, player)
    self.moveTimer = (self.moveTimer or 0) - dt
    if self.moveTimer > 0 then return end
    self.moveTimer = self.moveDelay or 0.5
    -- חפש אזור claimed קרוב לשחקן
    local pi, pj = player.i, player.j
    local bestDist = math.huge
    local bestMove = {self.i, self.j}
    local foundClaimed = false
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    for _, d in ipairs(dirs) do
        local ni, nj = self.i + d[1], self.j + d[2]
        if grid:isInside(ni, nj) and grid.cells[ni][nj] == 'claimed' then
            foundClaimed = true
            local dist = math.abs(ni-pi) + math.abs(nj-pj)
            if dist < bestDist then
                bestDist = dist
                bestMove = {ni, nj}
            end
        end
    end
    if foundClaimed then
        self.i, self.j = bestMove[1], bestMove[2]
        grid.cells[self.i][self.j] = 'empty' -- פורץ אזור
        self._justBroke = true
    else
        -- תנועה אקראית
        local d = dirs[math.random(#dirs)]
        local ni, nj = self.i + d[1], self.j + d[2]
        if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
            self.i, self.j = ni, nj
        end
        self._justBroke = false
    end
end

function GuardianBreaker:draw(grid)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    if self._justBroke then
        love.graphics.setColor(0.2,1,1,1)
    else
        love.graphics.setColor(0.2,0.8,1,1)
    end
    love.graphics.rectangle('fill', x-grid.cellSize*0.2, y-grid.cellSize*0.2, grid.cellSize*0.4, grid.cellSize*0.4, 6, 6)
    love.graphics.setColor(1,1,1)
end

return GuardianBreaker
