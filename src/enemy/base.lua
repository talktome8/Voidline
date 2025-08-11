local EnemyBase = {}
EnemyBase.__index = EnemyBase

function EnemyBase:new(i, j)
    local e = setmetatable({}, self)
    e.i = i or 10
    e.j = j or 10
    e.type = 'base'
    e.color = {0.8, 0.2, 0.2} -- Default enemy color
    e.speed = 1 -- cells per second
    e.moveDelay = 1.0 -- Faster movement for better challenge
    e.moveTimer = 0
    e.isStunned = false
    e.stunTimer = 0
    e.originalColor = nil
    e.speedBoost = nil
    
    -- Enhanced AI properties
    e.targetPlayer = false
    e.aggressionMultiplier = 1.0
    e.lastPlayerI = nil
    e.lastPlayerJ = nil
    e.huntMode = false
    
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

function EnemyBase:update(dt, grid, playerI, playerJ)
    -- Handle stun status first
    if self.isStunned then
        self.stunTimer = self.stunTimer - dt
        if self.stunTimer <= 0 then
            self.isStunned = false
            if self.originalColor then
                self.color = {self.originalColor[1], self.originalColor[2], self.originalColor[3]}
                self.originalColor = nil
            else
                self.color = {0.8, 0.2, 0.2} 
            end
        end
        return true -- Skip movement while stunned
    end

    -- Update visual effects
    if self._fuseHitTimer and self._fuseHitTimer > 0 then
        self._fuseHitTimer = self._fuseHitTimer - dt
        if self._fuseHitTimer <= 0 then
            self._fuseHitColor = nil
        end
    end

    -- Enhanced AI movement
    local actualSpeed = (self.speed or 1) * (self.aggressionMultiplier or 1.0)
    if self.speedBoost then
        actualSpeed = actualSpeed * self.speedBoost
    end
    
    self.moveTimer = (self.moveTimer or 0) - dt * actualSpeed

    if self.moveTimer <= 0 then
        self.moveTimer = self.moveDelay or 1.0
        
        -- Store player position for tracking
        if playerI and playerJ then
            self.lastPlayerI = playerI
            self.lastPlayerJ = playerJ
        end
        
        -- Enhanced movement AI
        local moveI, moveJ = self:calculateMovement(grid, playerI, playerJ)
        
        -- Validate movement
        if self:canMoveTo(grid, moveI, moveJ) then
            self.i = moveI
            self.j = moveJ
        end
    end
    
    return false
end

-- Enhanced movement AI
function EnemyBase:calculateMovement(grid, playerI, playerJ)
    if not playerI or not playerJ then
        return self:randomMovement()
    end
    
    -- Calculate distance to player
    local distToPlayer = math.sqrt((self.i - playerI)^2 + (self.j - playerJ)^2)
    
    -- Aggressive targeting when player is drawing
    if self.targetPlayer and distToPlayer > 1.5 then
        return self:moveTowardsPlayer(playerI, playerJ)
    elseif distToPlayer < 8 then
        -- Hunt mode - move towards player when nearby
        self.huntMode = true
        return self:moveTowardsPlayer(playerI, playerJ)
    else
        -- Patrol mode - random movement with slight bias towards center
        self.huntMode = false
        return self:patrolMovement(grid)
    end
end

function EnemyBase:moveTowardsPlayer(playerI, playerJ)
    local dx = playerI - self.i
    local dy = playerJ - self.j
    
    -- Add some randomness to avoid completely predictable movement
    local randomFactor = 0.3
    dx = dx + (math.random() - 0.5) * randomFactor
    dy = dy + (math.random() - 0.5) * randomFactor
    
    -- Normalize and move one step
    local moveI = self.i
    local moveJ = self.j
    
    if math.abs(dx) > math.abs(dy) then
        moveI = self.i + (dx > 0 and 1 or -1)
    else
        moveJ = self.j + (dy > 0 and 1 or -1)
    end
    
    return moveI, moveJ
end

function EnemyBase:patrolMovement(grid)
    -- Bias towards center of map for better shape interference
    local centerI = math.floor(grid.width / 2)
    local centerJ = math.floor(grid.height / 2)
    
    local toCenterI = centerI - self.i
    local toCenterJ = centerJ - self.j
    
    local moveI = self.i
    local moveJ = self.j
    
    -- 70% chance to move towards center, 30% random
    if math.random() < 0.7 and (math.abs(toCenterI) > 5 or math.abs(toCenterJ) > 5) then
        if math.abs(toCenterI) > math.abs(toCenterJ) then
            moveI = self.i + (toCenterI > 0 and 1 or -1)
        else
            moveJ = self.j + (toCenterJ > 0 and 1 or -1)
        end
    else
        -- Random movement
        local dirs = {{-1,0}, {1,0}, {0,-1}, {0,1}}
        local dir = dirs[math.random(#dirs)]
        moveI = self.i + dir[1]
        moveJ = self.j + dir[2]
    end
    
    return moveI, moveJ
end

function EnemyBase:randomMovement()
    local dirs = {{-1,0}, {1,0}, {0,-1}, {0,1}, {-1,-1}, {1,1}, {-1,1}, {1,-1}}
    local dir = dirs[math.random(#dirs)]
    return self.i + dir[1], self.j + dir[2]
end

function EnemyBase:canMoveTo(grid, newI, newJ)
    -- Check bounds
    if newI < 1 or newI > grid.width or newJ < 1 or newJ > grid.height then
        return false
    end
    
    -- Check if position is available (not claimed territory)
    if grid.cells[newI] and grid.cells[newI][newJ] == 'claimed' then
        return false
    end
    
    return true
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
