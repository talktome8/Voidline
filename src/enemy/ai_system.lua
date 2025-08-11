-- src/enemy/ai_system.lua
-- Advanced enemy AI system with pathfinding and adaptive behavior

local Config = require 'src.config'
local AISystem = {}

-- AI behavior types
AISystem.BehaviorType = {
    CHASER = "chaser",           -- Direct pursuit
    SMART = "smart",             -- Predictive movement
    INTERCEPTOR = "interceptor", -- Cut off player paths
    PATROLLER = "patroller",     -- Area denial
    ADAPTIVE = "adaptive",       -- Learns from player behavior
    SWARM = "swarm",            -- Coordinate with other enemies
    BOSS = "boss",              -- Special boss behavior
    PHANTOM = "phantom"         -- Phase through walls
}

-- Pathfinding using A* algorithm
function AISystem:findPath(startX, startY, targetX, targetY, grid, avoidTrails)
    avoidTrails = avoidTrails or false
    
    local function heuristic(x1, y1, x2, y2)
        return math.abs(x1 - x2) + math.abs(y1 - y2)
    end
    
    local function isValidPosition(x, y)
        if not grid:isInside(x, y) then return false end
        local cell = grid:getCell(x, y)
        if cell == 'claimed' or cell == 'island' then return false end
        if avoidTrails and cell == 'trail' then return false end
        return true
    end
    
    local openSet = {{x = startX, y = startY, g = 0, h = heuristic(startX, startY, targetX, targetY), parent = nil}}
    local closedSet = {}
    local openSetLookup = {[startX .. "," .. startY] = true}
    
    while #openSet > 0 do
        -- Find node with lowest f score
        local current = openSet[1]
        local currentIndex = 1
        
        for i = 2, #openSet do
            local f = openSet[i].g + openSet[i].h
            local currentF = current.g + current.h
            if f < currentF then
                current = openSet[i]
                currentIndex = i
            end
        end
        
        -- Remove current from open set
        table.remove(openSet, currentIndex)
        openSetLookup[current.x .. "," .. current.y] = nil
        
        -- Add to closed set
        closedSet[current.x .. "," .. current.y] = current
        
        -- Check if we reached the target
        if current.x == targetX and current.y == targetY then
            local path = {}
            local node = current
            while node do
                table.insert(path, 1, {x = node.x, y = node.y})
                node = node.parent
            end
            return path
        end
        
        -- Check neighbors
        local neighbors = {
            {x = current.x + 1, y = current.y},
            {x = current.x - 1, y = current.y},
            {x = current.x, y = current.y + 1},
            {x = current.x, y = current.y - 1}
        }
        
        for _, neighbor in ipairs(neighbors) do
            local key = neighbor.x .. "," .. neighbor.y
            
            if isValidPosition(neighbor.x, neighbor.y) and not closedSet[key] then
                local g = current.g + 1
                local h = heuristic(neighbor.x, neighbor.y, targetX, targetY)
                
                if not openSetLookup[key] then
                    table.insert(openSet, {
                        x = neighbor.x, 
                        y = neighbor.y, 
                        g = g, 
                        h = h, 
                        parent = current
                    })
                    openSetLookup[key] = true
                else
                    -- Check if this path is better
                    for i, node in ipairs(openSet) do
                        if node.x == neighbor.x and node.y == neighbor.y and g < node.g then
                            node.g = g
                            node.parent = current
                            break
                        end
                    end
                end
            end
        end
    end
    
    return nil -- No path found
end

-- Predict player movement based on current velocity and behavior patterns
function AISystem:predictPlayerPosition(player, timeAhead)
    timeAhead = timeAhead or 1.0
    
    local predX = player.x
    local predY = player.y
    
    if player.velocity then
        predX = predX + player.velocity.x * timeAhead
        predY = predY + player.velocity.y * timeAhead
    end
    
    -- Add some randomness to prevent perfect prediction
    local randomOffset = 2
    predX = predX + (math.random() - 0.5) * randomOffset
    predY = predY + (math.random() - 0.5) * randomOffset
    
    return math.floor(predX + 0.5), math.floor(predY + 0.5)
end

-- Calculate the best intercept point to cut off player
function AISystem:calculateInterceptPoint(enemyX, enemyY, playerX, playerY, playerVelX, playerVelY)
    -- Simple intercept calculation
    local timeToIntercept = 3.0 -- seconds ahead
    
    local interceptX = playerX + playerVelX * timeToIntercept
    local interceptY = playerY + playerVelY * timeToIntercept
    
    return math.floor(interceptX + 0.5), math.floor(interceptY + 0.5)
end

-- Chaser behavior: Direct pursuit with basic pathfinding
function AISystem:updateChaser(enemy, player, grid, dt)
    local path = self:findPath(
        math.floor(enemy.x + 0.5), math.floor(enemy.y + 0.5),
        math.floor(player.x + 0.5), math.floor(player.y + 0.5),
        grid, false
    )
    
    if path and #path > 1 then
        local nextStep = path[2]
        enemy.targetX = nextStep.x
        enemy.targetY = nextStep.y
    else
        -- Fallback to direct movement
        enemy.targetX = player.x
        enemy.targetY = player.y
    end
end

-- Smart behavior: Predictive movement with obstacle avoidance
function AISystem:updateSmart(enemy, player, grid, dt)
    local predX, predY = self:predictPlayerPosition(player, 2.0)
    
    local path = self:findPath(
        math.floor(enemy.x + 0.5), math.floor(enemy.y + 0.5),
        predX, predY, grid, true -- Avoid trails
    )
    
    if path and #path > 1 then
        local nextStep = path[2]
        enemy.targetX = nextStep.x
        enemy.targetY = nextStep.y
    else
        -- If no path to prediction, try direct path to player
        self:updateChaser(enemy, player, grid, dt)
    end
end

-- Interceptor behavior: Try to cut off player's path
function AISystem:updateInterceptor(enemy, player, grid, dt)
    local playerVelX = (player.velocity and player.velocity.x) or 0
    local playerVelY = (player.velocity and player.velocity.y) or 0
    
    local interceptX, interceptY = self:calculateInterceptPoint(
        enemy.x, enemy.y, player.x, player.y, playerVelX, playerVelY
    )
    
    local path = self:findPath(
        math.floor(enemy.x + 0.5), math.floor(enemy.y + 0.5),
        interceptX, interceptY, grid, false
    )
    
    if path and #path > 1 then
        local nextStep = path[2]
        enemy.targetX = nextStep.x
        enemy.targetY = nextStep.y
    else
        -- Fallback to smart behavior
        self:updateSmart(enemy, player, grid, dt)
    end
end

-- Patroller behavior: Guard specific areas and respond to player
function AISystem:updatePatroller(enemy, player, grid, dt)
    enemy.patrolTimer = (enemy.patrolTimer or 0) + dt
    
    -- Initialize patrol points if not set
    if not enemy.patrolPoints then
        enemy.patrolPoints = {
            {x = math.random(5, grid.width - 5), y = math.random(5, grid.height - 5)},
            {x = math.random(5, grid.width - 5), y = math.random(5, grid.height - 5)},
            {x = math.random(5, grid.width - 5), y = math.random(5, grid.height - 5)}
        }
        enemy.currentPatrolIndex = 1
    end
    
    -- Check if player is in detection range
    local distance = math.sqrt((player.x - enemy.x)^2 + (player.y - enemy.y)^2)
    
    if distance < Config.enemy.detectionRange then
        -- Chase player
        self:updateChaser(enemy, player, grid, dt)
    else
        -- Patrol
        local targetPoint = enemy.patrolPoints[enemy.currentPatrolIndex]
        local pointDistance = math.sqrt((targetPoint.x - enemy.x)^2 + (targetPoint.y - enemy.y)^2)
        
        if pointDistance < 2.0 then
            enemy.currentPatrolIndex = (enemy.currentPatrolIndex % #enemy.patrolPoints) + 1
        end
        
        enemy.targetX = targetPoint.x
        enemy.targetY = targetPoint.y
    end
end

-- Adaptive behavior: Learn and adapt to player patterns
function AISystem:updateAdaptive(enemy, player, grid, dt)
    -- Initialize learning system
    if not enemy.playerHistory then
        enemy.playerHistory = {}
        enemy.learningTimer = 0
        enemy.adaptationLevel = 0
    end
    
    enemy.learningTimer = enemy.learningTimer + dt
    
    -- Record player position every second
    if enemy.learningTimer >= 1.0 then
        table.insert(enemy.playerHistory, {x = player.x, y = player.y, time = love.timer.getTime()})
        enemy.learningTimer = 0
        
        -- Keep only recent history
        if #enemy.playerHistory > 10 then
            table.remove(enemy.playerHistory, 1)
        end
        
        enemy.adaptationLevel = math.min(enemy.adaptationLevel + 0.1, 1.0)
    end
    
    -- Use learned patterns to predict movement
    if #enemy.playerHistory > 3 then
        local avgVelX, avgVelY = 0, 0
        for i = 2, #enemy.playerHistory do
            local prev = enemy.playerHistory[i-1]
            local curr = enemy.playerHistory[i]
            avgVelX = avgVelX + (curr.x - prev.x)
            avgVelY = avgVelY + (curr.y - prev.y)
        end
        
        avgVelX = avgVelX / (#enemy.playerHistory - 1)
        avgVelY = avgVelY / (#enemy.playerHistory - 1)
        
        -- Predict based on learned velocity
        local predictionTime = 2.0 + enemy.adaptationLevel * 2.0
        local predX = player.x + avgVelX * predictionTime
        local predY = player.y + avgVelY * predictionTime
        
        enemy.targetX = predX
        enemy.targetY = predY
    else
        -- Fallback to smart behavior while learning
        self:updateSmart(enemy, player, grid, dt)
    end
end

-- Swarm behavior: Coordinate with other enemies
function AISystem:updateSwarm(enemy, player, grid, dt, allEnemies)
    -- Find nearby swarm members
    local swarmMembers = {}
    for _, otherEnemy in ipairs(allEnemies) do
        if otherEnemy ~= enemy and otherEnemy.behavior == AISystem.BehaviorType.SWARM then
            local distance = math.sqrt((otherEnemy.x - enemy.x)^2 + (otherEnemy.y - enemy.y)^2)
            if distance < 10 then -- Swarm radius
                table.insert(swarmMembers, otherEnemy)
            end
        end
    end
    
    -- Calculate swarm center
    local centerX, centerY = enemy.x, enemy.y
    if #swarmMembers > 0 then
        for _, member in ipairs(swarmMembers) do
            centerX = centerX + member.x
            centerY = centerY + member.y
        end
        centerX = centerX / (#swarmMembers + 1)
        centerY = centerY / (#swarmMembers + 1)
    end
    
    -- Move towards player while maintaining swarm cohesion
    local playerWeight = 0.7
    local swarmWeight = 0.3
    
    enemy.targetX = player.x * playerWeight + centerX * swarmWeight
    enemy.targetY = player.y * playerWeight + centerY * swarmWeight
end

-- Main update function
function AISystem:updateEnemy(enemy, player, grid, dt, allEnemies)
    if not enemy.behavior then
        enemy.behavior = AISystem.BehaviorType.CHASER
    end
    
    -- Store previous position for velocity calculation
    enemy.prevX = enemy.prevX or enemy.x
    enemy.prevY = enemy.prevY or enemy.y
    
    -- Update based on behavior type
    if enemy.behavior == AISystem.BehaviorType.CHASER then
        self:updateChaser(enemy, player, grid, dt)
    elseif enemy.behavior == AISystem.BehaviorType.SMART then
        self:updateSmart(enemy, player, grid, dt)
    elseif enemy.behavior == AISystem.BehaviorType.INTERCEPTOR then
        self:updateInterceptor(enemy, player, grid, dt)
    elseif enemy.behavior == AISystem.BehaviorType.PATROLLER then
        self:updatePatroller(enemy, player, grid, dt)
    elseif enemy.behavior == AISystem.BehaviorType.ADAPTIVE then
        self:updateAdaptive(enemy, player, grid, dt)
    elseif enemy.behavior == AISystem.BehaviorType.SWARM then
        self:updateSwarm(enemy, player, grid, dt, allEnemies)
    end
    
    -- Apply movement towards target
    if enemy.targetX and enemy.targetY then
        local dx = enemy.targetX - enemy.x
        local dy = enemy.targetY - enemy.y
        local distance = math.sqrt(dx*dx + dy*dy)
        
        if distance > 0.1 then
            local speed = enemy.speed or Config.enemy.baseMoveSpeed
            local moveX = (dx / distance) * speed * dt
            local moveY = (dy / distance) * speed * dt
            
            enemy.x = enemy.x + moveX
            enemy.y = enemy.y + moveY
        end
    end
    
    -- Update velocity for prediction systems
    enemy.velocity = {
        x = enemy.x - enemy.prevX,
        y = enemy.y - enemy.prevY
    }
    
    enemy.prevX = enemy.x
    enemy.prevY = enemy.y
end

return AISystem
