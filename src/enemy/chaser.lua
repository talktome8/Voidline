local EnemyBase = require 'src.enemy.base'
local Chaser = setmetatable({}, {__index = EnemyBase})
Chaser.__index = Chaser

function Chaser:new(i, j, level)
    local e = EnemyBase.new(self, i, j)
    e.type = 'chaser'
    if level and level % 5 == 0 then
        e.moveDelay = 1.0 -- boss: מעט מהיר יותר
        e.isBoss = true
        e.bossStunTimer = 0
        e.lastDir = nil
    else
        e.moveDelay = math.max(0.9 - 0.07 * (level-1), 0.45) -- מהירות גבוהה יותר בשלבים מתקדמים
    end
    e.moveTimer = 0
    e.level = level or 1
    print("Chaser:new | level:", e.level, "moveDelay:", e.moveDelay)
    return e
end

function Chaser:update(dt, grid, player)
    -- Chaser can only defeat the player by direct collision or trail collision (handled in game.lua)
    -- Never trigger game over by timer, random, or any other means!
    if self.isBoss and self.bossStunTimer and self.bossStunTimer > 0 then
        self.bossStunTimer = self.bossStunTimer - dt
        return
    end
    self.moveTimer = (self.moveTimer or 0) - dt
    while self.moveTimer <= 0 do
        self.moveTimer = self.moveTimer + self.moveDelay
        -- Always move only one cell per update, but allow multiple moves if moveDelay is very low
        local pi, pj = player.i, player.j
        local bestDist = math.huge
        local bestMove = {self.i, self.j}
        local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
        -- Shuffle directions for less predictable movement
        for i = #dirs, 2, -1 do
            local j = math.random(i)
            dirs[i], dirs[j] = dirs[j], dirs[i]
        end
        for _, d in ipairs(dirs) do
            local ni, nj = self.i + d[1], self.j + d[2]
            if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
                local dist = math.abs(ni-pi) + math.abs(nj-pj)
                if dist < bestDist then
                    bestDist = dist
                    bestMove = {ni, nj}
                end
            end
        end
        -- Add a small chance to move randomly if stuck
        if bestMove[1] == self.i and bestMove[2] == self.j and math.random() < 0.25 then
            local d = dirs[math.random(#dirs)]
            local ni, nj = self.i + d[1], self.j + d[2]
            if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
                bestMove = {ni, nj}
            end
        end
        -- Make chaser more aggressive as level increases
        local aggression = math.min(1, 0.15 + 0.07 * (self.level or 1))
        -- If player is drawing a trail, prioritize intercepting the trail
        if player.isDrawing and #player.trail > 0 and math.random() < aggression then
            local closestTrailNode, minTrailDist = nil, math.huge
            for _, node in ipairs(player.trail) do
                local dist = math.abs(self.i - node.i) + math.abs(self.j - node.j)
                if dist < minTrailDist then
                    minTrailDist = dist
                    closestTrailNode = node
                end
            end
            if closestTrailNode then
                local bestTrailDist = math.huge
                for _, d in ipairs(dirs) do
                    local ni, nj = self.i + d[1], self.j + d[2]
                    if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
                        local dist = math.abs(ni - closestTrailNode.i) + math.abs(nj - closestTrailNode.j)
                        if dist < bestTrailDist then
                            bestTrailDist = dist
                            bestMove = {ni, nj}
                        end
                    end
                end
            end
        end
        -- Occasionally allow diagonal movement at higher levels
        if self.level and self.level >= 6 and math.random() < 0.18 then
            local diagDirs = {{1,1},{-1,1},{1,-1},{-1,-1}}
            for _, d in ipairs(diagDirs) do
                local ni, nj = self.i + d[1], self.j + d[2]
                if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
                    local dist = math.abs(ni-pi) + math.abs(nj-pj)
                    if dist < bestDist then
                        bestDist = dist
                        bestMove = {ni, nj}
                    end
                end
            end
        end
        self.i, self.j = bestMove[1], bestMove[2]
        -- At higher levels, small chance to move again immediately
        if self.level and self.level >= 5 and math.random() < 0.15 then
            self.moveTimer = 0.01 -- move again next frame
        end
    end
    -- Update proximity flag for visuals
    local pi, pj = player.i, player.j
    if math.abs(self.i - pi) + math.abs(self.j - pj) <= 2 then
        self._closeToPlayer = true
    else
        self._closeToPlayer = false
    end
end

-- איפוס דגל התנועה בכל פריים (יש להוסיף לקריאה מהמשחק)
function Chaser:resetMoveFlag()
    self._movedThisFrame = false
end

function Chaser:draw(grid)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    if self._closeToPlayer then
        love.graphics.setColor(1,0.2+0.5*math.abs(math.sin(love.timer.getTime()*8)),0.2,1)
    else
        love.graphics.setColor(0.8,0.2,0.2,1)
    end
    -- Unique: Chaser is a red diamond
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(math.pi/4)
    love.graphics.rectangle('fill', -grid.cellSize*0.21, -grid.cellSize*0.21, grid.cellSize*0.42, grid.cellSize*0.42, 4, 4)
    love.graphics.pop()
    love.graphics.setColor(1,1,1)
end

return Chaser
