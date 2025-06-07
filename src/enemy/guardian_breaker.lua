-- GuardianBreaker enemy: hunts Guardian, destroys fuse defuse ability if close
local EnemyBase = require('src.enemy.base')
local GuardianBreaker = setmetatable({}, {__index = EnemyBase})
GuardianBreaker.__index = GuardianBreaker

function GuardianBreaker:new(i, j)
    local self = setmetatable(EnemyBase:new(i, j), GuardianBreaker)
    self.color = {1, 0.2, 0.2}
    self.targetType = "Guardian"
    self.moveDelay = 1.2 -- always fair
    self.moveTimer = 0
    return self
end

function GuardianBreaker:update(dt, grid, player)
    self.moveTimer = (self.moveTimer or 0) - dt
    if self.moveTimer > 0 then return end
    self.moveTimer = self.moveDelay
    -- Always move only one cell per update, toward player
    local pi, pj = player.i, player.j
    local bestDist = math.huge
    local bestMove = {self.i, self.j}
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
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
    self.i, self.j = bestMove[1], bestMove[2]
end

function GuardianBreaker:draw(grid)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    -- Unique: GuardianBreaker is a cyan hexagon
    love.graphics.setColor(0.2,0.8,1,1)
    local r = grid.cellSize*0.22
    local points = {}
    for i=0,5 do
        local angle = math.pi/3 * i
        table.insert(points, x + r*math.cos(angle))
        table.insert(points, y + r*math.sin(angle))
    end
    love.graphics.polygon('fill', points)
    love.graphics.setColor(1,1,1)
end

return GuardianBreaker
