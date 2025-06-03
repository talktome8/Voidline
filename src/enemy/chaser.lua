local EnemyBase = require 'src.enemy.base'
local Chaser = setmetatable({}, {__index = EnemyBase})
Chaser.__index = Chaser

function Chaser:new(i, j, level)
    local e = EnemyBase.new(self, i, j)
    e.type = 'chaser'
    -- האטה נוספת בשלבים מתקדמים
    if level and level >= 2 then
        e.moveDelay = 0.45
    else
        e.moveDelay = 0.3
    end
    e.moveTimer = 0
    e.level = level or 1
    print("Chaser:new | level:", e.level, "moveDelay:", e.moveDelay)
    return e
end

function Chaser:update(dt, grid, player)
    self.moveTimer = self.moveTimer - dt
    if self.moveTimer > 0 then return end
    self.moveTimer = self.moveDelay -- תמיד לאתחל ל-moveDelay בלבד
    local pi, pj = player.i, player.j
    local bestDist = math.huge
    local bestMove = {self.i, self.j}
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    local possibleMoves = {}
    local fartherMoves = {}
    local myDist = math.abs(self.i-pi) + math.abs(self.j-pj)
    for _, d in ipairs(dirs) do
        local ni, nj = self.i + d[1], self.j + d[2]
        if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
            local dist = math.abs(ni-pi) + math.abs(nj-pj)
            table.insert(possibleMoves, {ni, nj, dist})
            if dist < bestDist then
                bestDist = dist
                bestMove = {ni, nj}
            end
            if dist > myDist then
                table.insert(fartherMoves, {ni, nj, dist})
            end
        end
    end
    -- 99% מהפעמים יעדיף להתרחק אם אפשר
    local randomChance = 0.99
    if #fartherMoves > 0 and math.random() < randomChance then
        local idx = math.random(1, #fartherMoves)
        bestMove = {fartherMoves[idx][1], fartherMoves[idx][2]}
    elseif #possibleMoves > 0 and math.random() < 0.5 then
        local idx = math.random(1, #possibleMoves)
        bestMove = {possibleMoves[idx][1], possibleMoves[idx][2]}
    end
    if bestDist <= 2 then
        if not self._forcedSlow then
            self.moveTimer = self.moveTimer * 0.5
        end
        self._closeToPlayer = true
    else
        self._closeToPlayer = false
    end
    -- Guarantee: if _forcedSlow, moveTimer must be at least moveDelay
    if self._forcedSlow and self.moveTimer < self.moveDelay then
        self.moveTimer = self.moveDelay
    end
    self.i, self.j = bestMove[1], bestMove[2]
end

function Chaser:draw(grid)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    if self._closeToPlayer then
        love.graphics.setColor(1,0.2+0.5*math.abs(math.sin(love.timer.getTime()*8)),0.2,1)
    else
        love.graphics.setColor(0.8,0.2,0.2,1)
    end
    love.graphics.circle('fill', x, y, grid.cellSize*0.3)
    love.graphics.setColor(1,1,1)
end

return Chaser
