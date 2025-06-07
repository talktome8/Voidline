-- src/enemy/splitter.lua
-- Splitter enemy: splits into two when trapped (no valid moves)
local EnemyBase = require 'src.enemy.base'
local Splitter = setmetatable({}, {__index = EnemyBase})
Splitter.__index = Splitter

function Splitter:new(i, j, level)
    local e = EnemyBase.new(self, i, j)
    e.type = 'splitter'
    e.moveDelay = 1.1 - 0.02 * (level or 1)
    e.moveTimer = 0
    e.level = level or 1
    e.splitCount = 0
    return e
end

function Splitter:update(dt, grid, player)
    self.moveTimer = self.moveTimer - dt
    if self.moveTimer > 0 then return end
    self.moveTimer = self.moveDelay
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    local options = {}
    for _, d in ipairs(dirs) do
        local ni, nj = self.i + d[1], self.j + d[2]
        if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
            table.insert(options, {ni, nj})
        end
    end
    if #options > 0 then
        local pick = options[math.random(#options)]
        self.i, self.j = pick[1], pick[2]
    elseif self.splitCount < 2 and grid.enemies then
        -- Split into two new Splitters if trapped, only once
        for _, d in ipairs(dirs) do
            local ni, nj = self.i + d[1], self.j + d[2]
            if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
                table.insert(grid.enemies, Splitter:new(ni, nj, self.level))
            end
        end
        self.splitCount = self.splitCount + 1
    end
end

function Splitter:draw(grid)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    love.graphics.setColor(1, 0.7, 0.2, 1)
    love.graphics.circle('fill', x, y, grid.cellSize*0.18, 24)
    love.graphics.setColor(1,1,1)
end

return Splitter
