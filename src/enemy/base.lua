local EnemyBase = {}
EnemyBase.__index = EnemyBase

function EnemyBase:new(i, j)
    local e = setmetatable({}, self)
    e.i = i
    e.j = j
    e.type = 'base'
    e.color = {0.8, 0.2, 0.2} -- Default enemy color
    e.speed = 1 -- cells per second
    e.moveDelay = 1.2 -- Default moveDelay for all enemies
    e.moveTimer = 0
    e.isStunned = false
    e.stunTimer = 0
    e.originalColor = nil
    e.speedBoost = nil -- Initialize speedBoost
    return e
end

function EnemyBase:setStunned(duration)
    if not self.isStunned then -- Only apply if not already stunned, or re-apply stun
        self.originalColor = {self.color[1], self.color[2], self.color[3]}
    end
    self.isStunned = true
    self.stunTimer = duration
    self.color = {0.5, 0.5, 1, 0.9} -- Light blue stun color
end

function EnemyBase:load(grid)
    -- Override in child
end

function EnemyBase:hitByFuse()
    -- Visual feedback: flash white, then return to normal
    self._fuseHitTimer = 0.4
    self._fuseHitColor = {1, 1, 1, 1}
end

function EnemyBase:update(dt, grid, player)
    -- ABSOLUTE BLOCK: If forced slow is set and moveDelay >= 900 or speed < 0.01, do not move at all
    if (self._forcedSlow and (self.moveDelay and self.moveDelay >= 900 or self.speed and self.speed < 0.01)) then
        print('ENEMYBASE BLOCKED:', self.type, 'moveDelay:', self.moveDelay, 'speed:', self.speed)
        return true -- Block all movement
    end
    -- DEBUG: Print type and moveDelay every frame for all enemies
    print('ENEMYBASE UPDATE:', self.type, 'moveDelay:', self.moveDelay, 'speed:', self.speed)
    local actualSpeed = self.speed or 1
    if self.speedBoost then
        actualSpeed = actualSpeed * self.speedBoost
    end
    self.moveTimer = (self.moveTimer or 0) - dt * actualSpeed

    -- Fuse hit visual effect
    if self._fuseHitTimer and self._fuseHitTimer > 0 then
        self._fuseHitTimer = self._fuseHitTimer - dt
        if self._fuseHitTimer <= 0 then
            self._fuseHitColor = nil
        end
    end

    if self.isStunned then
        self.stunTimer = self.stunTimer - dt
        if self.stunTimer <= 0 then
            self.isStunned = false
            if self.originalColor then
                self.color = {self.originalColor[1], self.originalColor[2], self.originalColor[3]}
                self.originalColor = nil
            else
                -- Fallback if originalColor wasn't set (should not happen with current setStunned logic)
                self.color = {0.8, 0.2, 0.2} 
            end
        end
        -- While stunned, an enemy might still be vulnerable or have minimal animation
        -- For now, they just won't perform their main logic (like moving)
        return true -- Indicate that the update was handled (stunned)
    end
    return false -- Indicate not stunned, proceed with specific enemy logic
end

function EnemyBase:draw(grid)
    if self._fuseHitColor then
        love.graphics.setColor(self._fuseHitColor)
    else
        love.graphics.setColor(self.color)
    end
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    love.graphics.circle('fill', x, y, grid.cellSize*0.3)
    love.graphics.setColor(1,1,1)
end

-- Infester enemy: infects claimed zones, can only be removed by closure
local Infester = setmetatable({}, {__index = EnemyBase})
Infester.__index = Infester

function Infester:new(i, j, level)
    local e = EnemyBase.new(self, i, j)
    e.type = 'infester'
    e.moveDelay = 1.5
    e.moveTimer = 0
    e.level = level or 1
    e.infectTimer = 0
    return e
end

function Infester:update(dt, grid, player)
    self.moveTimer = self.moveTimer - dt
    if self.moveTimer > 0 then return end
    self.moveTimer = self.moveDelay
    -- Infect claimed zones
    if grid.cells[self.i] and grid.cells[self.i][self.j] == 'claimed' then
        grid.cells[self.i][self.j] = 'infected'
    end
    -- Move randomly inside claimed or infected zones
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    local moves = {}
    for _, d in ipairs(dirs) do
        local ni, nj = self.i + d[1], self.j + d[2]
        if grid:isInside(ni, nj) and (grid.cells[ni][nj] == 'claimed' or grid.cells[ni][nj] == 'infected') then
            table.insert(moves, {ni, nj})
        end
    end
    if #moves > 0 then
        local idx = math.random(1, #moves)
        self.i, self.j = moves[idx][1], moves[idx][2]
    end
end

function Infester:draw(grid)
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    love.graphics.setColor(0.3, 1, 0.3, 1)
    love.graphics.circle('fill', x, y, grid.cellSize*0.28)
    love.graphics.setColor(1,1,1)
end

return EnemyBase, Infester
