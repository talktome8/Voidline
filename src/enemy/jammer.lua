local EnemyBase = require 'src.enemy.base'
local Jammer = setmetatable({}, {__index = EnemyBase})
Jammer.__index = Jammer

function Jammer:new(i, j)
    local e = EnemyBase.new(self, i, j)
    e.type = 'jammer'
    e.moveDelay = 0.5
    e.moveTimer = 0
    return e
end

function Jammer:update(dt, grid, player)
    self.moveTimer = self.moveTimer - dt
    if self.moveTimer > 0 then return end
    self.moveTimer = self.moveDelay
    -- תנועה אקראית
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    local options = {}
    for _, d in ipairs(dirs) do
        local ni, nj = self.i + d[1], self.j + d[2]
        if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
            table.insert(options, {i=ni, j=nj})
        end
    end
    if #options > 0 then
        local pick = options[math.random(#options)]
        self.i, self.j = pick.i, pick.j
    end
    -- משבש: הופך את ה-trail של השחקן לבלתי נראה זמנית
    grid._jammedTrail = 1.0
end

function Jammer:draw(grid)
    love.graphics.setColor(0.7, 0.1, 0.7)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    love.graphics.circle('fill', x, y, grid.cellSize*0.33)
    love.graphics.setColor(1,1,1)
end

return Jammer
