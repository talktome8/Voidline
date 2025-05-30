local EnemyBase = require 'src.enemy.base'
local Chaser = setmetatable({}, {__index = EnemyBase})
Chaser.__index = Chaser

function Chaser:new(i, j)
    local e = EnemyBase.new(self, i, j)
    e.type = 'chaser'
    e.moveDelay = 0.3
    e.moveTimer = 0
    return e
end

function Chaser:update(dt, grid, player)
    self.moveTimer = self.moveTimer - dt
    if self.moveTimer > 0 then return end
    self.moveTimer = self.moveDelay
    local di = player.i - self.i
    local dj = player.j - self.j
    local moveI, moveJ = 0, 0
    if math.abs(di) > math.abs(dj) then
        moveI = (di > 0) and 1 or (di < 0 and -1 or 0)
    elseif dj ~= 0 then
        moveJ = (dj > 0) and 1 or -1
    end
    local ni, nj = self.i + moveI, self.j + moveJ
    if grid:isInside(ni, nj) and not grid:isClaimed(ni, nj) then
        self.i, self.j = ni, nj
    end
end

return Chaser
