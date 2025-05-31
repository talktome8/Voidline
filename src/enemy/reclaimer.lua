local EnemyBase = require 'src.enemy.base'
local Reclaimer = setmetatable({}, {__index = EnemyBase})
Reclaimer.__index = Reclaimer

function Reclaimer:new(i, j)
    local e = EnemyBase.new(self, i, j)
    e.type = 'reclaimer'
    e.moveDelay = 0.45
    e.moveTimer = 0
    return e
end

function Reclaimer:update(dt, grid, player)
    self.moveTimer = self.moveTimer - dt
    if self.moveTimer > 0 then return end
    self.moveTimer = self.moveDelay
    -- בוחר תא claimed אקראי סמוך והופך אותו ל-empty ("פותח אזור")
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    local options = {}
    for _, d in ipairs(dirs) do
        local ni, nj = self.i + d[1], self.j + d[2]
        if grid:isInside(ni, nj) and grid.cells[ni][nj] == 'claimed' then
            table.insert(options, {i=ni, j=nj})
        end
    end
    if #options > 0 then
        local pick = options[math.random(#options)]
        grid.cells[pick.i][pick.j] = 'empty'
    end
    -- תנועה פשוטה לכיוון השחקן
    local di = player.i - self.i
    local dj = player.j - self.j
    local moveI, moveJ = 0, 0
    if math.abs(di) > math.abs(dj) then
        moveI = (di > 0) and 1 or (di < 0 and -1 or 0)
    elseif dj ~= 0 then
        moveJ = (dj > 0) and 1 or -1
    end
    local ni, nj = self.i + moveI, self.j + moveJ
    if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
        self.i, self.j = ni, nj
    end
end

function Reclaimer:draw(grid)
    love.graphics.setColor(0.7, 0.3, 0.1)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    love.graphics.circle('fill', x, y, grid.cellSize*0.33)
    love.graphics.setColor(1,1,1)
end

return Reclaimer
