-- src/enemy/infester.lua
-- Infester enemy: infects claimed zones, can only be removed by closure
local EnemyBase = require 'src.enemy.base'
local Infester = setmetatable({}, {__index = EnemyBase})
Infester.__index = Infester

function Infester:new(i, j, level)
    local e = EnemyBase.new(self, i, j)
    e.type = 'infester'
    e.moveDelay = 1.1 - 0.03 * (level or 1)
    e.moveTimer = 0
    e.level = level or 1
    e._multiplyTimer = 0
    return e
end

function Infester:update(dt, grid, player)
    self.moveTimer = self.moveTimer - dt
    self._multiplyTimer = (self._multiplyTimer or 0) + dt
    if self.moveTimer <= 0 then
        self.moveTimer = self.moveDelay
        -- Move to random adjacent non-claimed cell (prefer empty, fallback to infected)
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
        end
        -- Infect cell
        if grid.cells[self.i][self.j] ~= 'claimed' then
            grid.cells[self.i][self.j] = 'infected'
        end
    end
    -- Multiply every 10 seconds (if enough space)
    if self._multiplyTimer > 10 then
        self._multiplyTimer = 0
        local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
        local spawnOptions = {}
        for _, d in ipairs(dirs) do
            local ni, nj = self.i + d[1], self.j + d[2]
            if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' and grid.cells[ni][nj] ~= 'infected' then
                table.insert(spawnOptions, {ni, nj})
            end
        end
        if #spawnOptions > 0 and grid.enemies then
            local pick = spawnOptions[math.random(#spawnOptions)]
            table.insert(grid.enemies, Infester:new(pick[1], pick[2], self.level))
        end
    end
end

function Infester:draw(grid)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    -- Unique: Infester is a green triangle
    love.graphics.setColor(0.3, 1, 0.3, 1)
    love.graphics.polygon('fill', x, y-grid.cellSize*0.18, x+grid.cellSize*0.16, y+grid.cellSize*0.14, x-grid.cellSize*0.16, y+grid.cellSize*0.14)
    love.graphics.setColor(1,1,1)
end

return Infester
