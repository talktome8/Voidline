-- src/enemy/phaser.lua
-- Phaser enemy: can occasionally move through claimed cells
local EnemyBase = require 'src.enemy.base'
local Phaser = setmetatable({}, {__index = EnemyBase})
Phaser.__index = Phaser

function Phaser:new(i, j, level)
    local e = EnemyBase.new(self, i, j)
    e.type = 'phaser'
    e.moveDelay = 1.0 - 0.02 * (level or 1)
    e.moveTimer = 0
    e.level = level or 1
    return e
end

function Phaser:update(dt, grid, player)
    self.moveTimer = self.moveTimer - dt
    if self.moveTimer > 0 then return end
    self.moveTimer = self.moveDelay
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    local options = {}
    local canPhase = math.random() < 0.18
    for _, d in ipairs(dirs) do
        local ni, nj = self.i + d[1], self.j + d[2]
        local cell = grid.cells[ni] and grid.cells[ni][nj]
        if grid:isInside(ni, nj) and (cell ~= 'claimed' or canPhase) then
            table.insert(options, {ni, nj})
        end
    end
    if #options > 0 then
        local pick = options[math.random(#options)]
        self.i, self.j = pick[1], pick[2]
    end
end

function Phaser:draw(grid)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    love.graphics.setColor(0.7, 0.2, 1, 1)
    love.graphics.rectangle('fill', x-grid.cellSize*0.14, y-grid.cellSize*0.14, grid.cellSize*0.28, grid.cellSize*0.28, 8, 8)
    love.graphics.setColor(1,1,1)
end

return Phaser
