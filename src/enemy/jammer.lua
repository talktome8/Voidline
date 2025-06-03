local EnemyBase = require 'src.enemy.base'
local Jammer = setmetatable({}, {__index = EnemyBase})
Jammer.__index = Jammer

function Jammer:new(i, j, level)
    local e = EnemyBase.new(self, i, j)
    e.type = 'jammer'
    -- האטה משמעותית ברמות 2+
    if level and level >= 2 then
        e.moveDelay = math.max(1.2 - 0.1 * (level-2), 0.5) -- לא פחות מ-0.5
    else
        e.moveDelay = 0.5
    end
    e.moveTimer = 0
    e.level = level or 1
    print('DEBUG: Jammer:new - level:', level, 'moveDelay:', e.moveDelay)
    return e
end

function Jammer:update(dt, grid, player)
    self.moveTimer = self.moveTimer - dt
    if self.moveTimer > 0 then return end
    -- הגנה: אל תאפשר מהירות איטית מדי (לא פחות מ-0.7)
    self.moveDelay = math.max(self.moveDelay, 0.7)
    self.moveTimer = self.moveDelay
    -- שדרוג: נסה להתקרב לשחקן, אך 90% מהפעמים יעדיף להתרחק ברמות 2+
    local pi, pj = player.i, player.j
    local bestDist = math.abs(self.i-pi) + math.abs(self.j-pj)
    local bestMove = {self.i, self.j}
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    local fartherMoves = {}
    for _, d in ipairs(dirs) do
        local ni, nj = self.i + d[1], self.j + d[2]
        if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
            local dist = math.abs(ni-pi) + math.abs(nj-pj)
            if dist < bestDist then
                bestDist = dist
                bestMove = {ni, nj}
            end
            if dist > bestDist then
                table.insert(fartherMoves, {ni, nj, dist})
            end
        end
    end
    local randomChance = 0.1
    if (self.level or 1) >= 2 and #fartherMoves > 0 and math.random() > randomChance then
        local idx = math.random(1, #fartherMoves)
        bestMove = {fartherMoves[idx][1], fartherMoves[idx][2]}
    end
    self.i, self.j = bestMove[1], bestMove[2]
    -- אם קרוב לשחקן, הפעל jam חזק
    if bestDist <= 1 and (not player.isJammed or (player.jamTimer or 0) <= 0) then
        player.isJammed = true
        player.jamTimer = 3
        self.jamCooldown = 5
    end
    if self.jamCooldown and self.jamCooldown > 0 then
        self.jamCooldown = self.jamCooldown - dt
    end
end

function Jammer:draw(grid)
    love.graphics.setColor(0.7, 0.1, 0.7)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    love.graphics.circle('fill', x, y, grid.cellSize*0.33)
    -- אפקט: אם השחקן משותק, צייר הילה
    if self.jamCooldown and self.jamCooldown > 4 then
        love.graphics.setColor(0.7,0.3,0.9,0.5)
        love.graphics.circle('line', x, y, grid.cellSize*0.5, 32)
    end
    love.graphics.setColor(1,1,1)
end

return Jammer
