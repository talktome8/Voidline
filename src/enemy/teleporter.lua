-- src/enemy/teleporter.lua
local EnemyBase = require 'src.enemy.base'
local Teleporter = setmetatable({}, {__index = EnemyBase})
Teleporter.__index = Teleporter

function Teleporter:new(i, j)
    local self = setmetatable(EnemyBase:new(i, j), Teleporter)
    self.type = 'teleporter'
    self.color = {0.5, 0.2, 1}
    self.teleportCooldown = 3
    self.teleportTimer = 3
    return self
end

function Teleporter:update(dt, grid, player)
    self.teleportTimer = self.teleportTimer - dt
    if self.teleportTimer <= 0 then
        -- Teleport to random empty cell
        local found = false
        for _=1,20 do
            local ni = math.random(2, grid.width-1)
            local nj = math.random(2, grid.height-1)
            if grid.cells[ni][nj] == 'empty' then
                self.i, self.j = ni, nj
                found = true
                break
            end
        end
        self.teleportTimer = self.teleportCooldown
    end
    -- Otherwise, basic chase
    EnemyBase.update(self, dt, grid, player)
end

function Teleporter:draw(grid)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    love.graphics.setColor(self.color)
    love.graphics.circle('fill', x, y, grid.cellSize*0.32, 24)
    -- Teleport aura
    local pulse = 0.18 + 0.18*math.abs(math.sin(love.timer.getTime()*2))
    love.graphics.setColor(0.7,0.5,1,0.18+pulse)
    love.graphics.circle('line', x, y, grid.cellSize*0.5+6*pulse, 24)
    love.graphics.setColor(1,1,1)
end

return Teleporter
