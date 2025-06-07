-- The Reclaimer Boss: periodically reclaims closed zones, immune to traps
local EnemyBase = require('src.enemy.base')
local ReclaimerBoss = setmetatable({}, {__index = EnemyBase})
ReclaimerBoss.__index = ReclaimerBoss

function ReclaimerBoss:new(i, j)
    local self = setmetatable(EnemyBase:new(i, j), ReclaimerBoss)
    self.color = {0.8, 0.1, 0.8}
    self.name = "The Reclaimer"
    self.reclaimTimer = 16 -- היה 12, היה 8
    self.reclaimCooldown = 16 -- היה 12, היה 8
    self.moveDelay = 1.2
    self.moveTimer = 0
    return self
end

function ReclaimerBoss:update(dt, grid, player)
    if EnemyBase.update(self, dt, grid, player) then return end
    self.reclaimTimer = self.reclaimTimer - dt
    -- ביטול האצת אויבים אחרים: לא נוגעים ב-enemy.moveDelay
    if self.reclaimTimer <= 0 then
        self:reclaimZone(grid)
        self.reclaimTimer = self.reclaimCooldown
    end
    -- Move randomly or toward player
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    local d = dirs[math.random(#dirs)]
    local ni, nj = self.i + d[1], self.j + d[2]
    if grid:isInside(ni, nj) and grid.cells[ni][nj] ~= 'claimed' then
        self.i, self.j = ni, nj
    end
end

function ReclaimerBoss:reclaimZone(grid)
    -- Reclaim a random large zone (cluster of claimed cells)
    local claimed = {}
    for i=2,grid.width-1 do
        for j=2,grid.height-1 do
            if grid.cells[i][j] == 'claimed' then
                -- Check for cluster: at least 2 neighbors claimed
                local neighbors = 0
                for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
                    local ni, nj = i+d[1], j+d[2]
                    if grid:isInside(ni, nj) and grid.cells[ni][nj] == 'claimed' then
                        neighbors = neighbors + 1
                    end
                end
                if neighbors >= 2 then
                    table.insert(claimed, {i=i, j=j})
                end
            end
        end
    end
    if #claimed > 0 then
        for n=1,math.min(2,#claimed) do -- היה 3, היה 6
            local idx = math.random(#claimed)
            local cell = claimed[idx]
            grid.cells[cell.i][cell.j] = 'empty'
            table.remove(claimed, idx)
        end
    end
end

function ReclaimerBoss:draw(grid)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    -- Unique: Boss is a magenta star with aura
    love.graphics.setColor(0.8, 0.1, 0.8)
    local r = grid.cellSize*0.28
    local points = {}
    for i=1,10 do
        local angle = (i-1)*math.pi/5
        local rad = (i%2==1) and r or r*0.55
        table.insert(points, x + math.cos(angle)*rad)
        table.insert(points, y + math.sin(angle)*rad)
    end
    love.graphics.polygon('fill', points)
    -- Draw boss aura (pulses when about to reclaim)
    local pulse = 0.18 + 0.18*math.abs(math.sin(love.timer.getTime()*2))
    if self.reclaimTimer and self.reclaimTimer < 2 then
        love.graphics.setColor(0.8, 0.1, 0.8, 0.35 + 0.35*pulse)
        love.graphics.circle('fill', x, y, grid.cellSize*(0.7+pulse))
    else
        love.graphics.setColor(0.8, 0.1, 0.8, 0.18)
        love.graphics.circle('fill', x, y, grid.cellSize*0.7)
    end
    love.graphics.setColor(1,1,1)
end

return ReclaimerBoss
