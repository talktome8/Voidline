-- Enemy: Jammer - disables and slows the player in an area. All jam logic is handled here.
local EnemyBase = require 'src.enemy.base'
local Jammer = setmetatable({}, {__index = EnemyBase})
Jammer.__index = Jammer

function Jammer:new(i, j, level)
    local e = EnemyBase.new(self, i, j)
    e.type = 'jammer'
    e.moveDelay = 1.2 -- always fair, never too fast
    e.moveTimer = 0
    e.level = level or 1
    do local ok, Config = pcall(require, 'src.config'); if ok and Config.debug and Config.debug.enabled then print('DEBUG: Jammer:new - level:', level, 'moveDelay:', e.moveDelay) end end
    return e
end

function Jammer:update(dt, grid, player)
    self.moveTimer = self.moveTimer - dt
    if self.moveTimer > 0 then return end
    self.moveTimer = self.moveDelay
    -- Always move only one cell per update, away from player
    local pi, pj = player.i, player.j
    local bestDist = math.abs(self.i-pi) + math.abs(self.j-pj)
    local bestMove = {self.i, self.j}
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    for _, d in ipairs(dirs) do
        local ni, nj = self.i + d[1], self.j + d[2]
        if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
            local dist = math.abs(ni-pi) + math.abs(nj-pj)
            if dist > bestDist then
                bestDist = dist
                bestMove = {ni, nj}
            end
        end
    end
    self.i, self.j = bestMove[1], bestMove[2]
    -- Jammer effect: area slow and disable
    self:applyJammingEffect(player, grid)
end

function Jammer:applyJammingEffect(player, grid)
    local ex = grid.offsetX + (self.i-0.5)*grid.cellSize
    local ey = grid.offsetY + (self.j-0.5)*grid.cellSize
    local px = grid.offsetX + (player.i-0.5)*grid.cellSize
    local py = grid.offsetY + (player.j-0.5)*grid.cellSize
    local dist = ((ex-px)^2 + (ey-py)^2)^0.5
    local radius = grid.cellSize*2.5
    if dist < radius then
        player.isJammed = true
        player.jamTimer = 0.2
    end
end

function Jammer:draw(grid)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    -- Unique: Jammer is a purple ring with a dot
    love.graphics.setColor(0.7,0.2,1,0.10)
    love.graphics.circle('fill', x, y, grid.cellSize*2.5)
    love.graphics.setColor(0.7, 0.1, 0.7)
    love.graphics.circle('line', x, y, grid.cellSize*0.33, 32)
    love.graphics.setColor(0.7, 0.1, 0.7, 0.7)
    love.graphics.circle('fill', x, y, grid.cellSize*0.13)
    love.graphics.setColor(1,1,1)
end

return Jammer
