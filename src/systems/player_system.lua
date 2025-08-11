-- src/systems/player_system.lua
-- Enhanced player movement and trail system

local Config = require 'src.config'
local PlayerSystem = {}

function PlayerSystem:init()
    self.player = {
        x = 2,
        y = 2,
        prevX = 2,
        prevY = 2,
        velocity = {x = 0, y = 0},
        trail = {},
        isDrawing = false,
        lives = Config.player.startingLives,
        invulnerable = false,
        invulnerabilityTimer = 0,
        moveTimer = 0,
        score = 0,
        abilitiesUsed = 0,
        
        -- Animation properties
        animationTimer = 0,
        pulseScale = 1.0,
        
        -- Input buffering for responsive controls
        inputBuffer = {},
        lastDirection = {x = 0, y = 0},
        
        -- Character-specific properties
        character = nil,
        speedModifier = 1,
        scoreMultiplier = 1,
        trailLengthBonus = 0
    }
    
    return self.player
end

function PlayerSystem:update(player, dt, grid)
    -- Update timers
    player.moveTimer = player.moveTimer + dt
    player.animationTimer = player.animationTimer + dt
    player.pulseScale = 1.0 + math.sin(player.animationTimer * 6) * 0.1
    
    -- Handle invulnerability
    if player.invulnerable then
        player.invulnerabilityTimer = player.invulnerabilityTimer - dt
        if player.invulnerabilityTimer <= 0 then
            player.invulnerable = false
        end
    end
    
    -- Handle movement
    local moveSpeed = 1.0 / Config.player.moveSpeed -- Time between moves
    if player.moveTimer >= moveSpeed then
        self:handleMovement(player, grid)
        player.moveTimer = 0
    end
    
    -- Update velocity for prediction systems
    player.velocity.x = player.x - player.prevX
    player.velocity.y = player.y - player.prevY
    player.prevX = player.x
    player.prevY = player.y
end

function PlayerSystem:handleMovement(player, grid)
    local newX, newY = player.x, player.y
    local direction = {x = 0, y = 0}
    
    -- Get input direction
    if love.keyboard.isDown("up", "w") then
        newY = newY - 1
        direction.y = -1
    elseif love.keyboard.isDown("down", "s") then
        newY = newY + 1
        direction.y = 1
    elseif love.keyboard.isDown("left", "a") then
        newX = newX - 1
        direction.x = -1
    elseif love.keyboard.isDown("right", "d") then
        newX = newX + 1
        direction.x = 1
    end
    
    -- Store direction for AI prediction
    if direction.x ~= 0 or direction.y ~= 0 then
        player.lastDirection = direction
    end
    
    -- Validate movement
    if self:isValidMove(newX, newY, grid) then
        self:movePlayer(player, newX, newY, grid)
    end
end

function PlayerSystem:isValidMove(x, y, grid)
    if not grid:isInside(x, y) then
        return false
    end
    
    local cell = grid:getCell(x, y)
    -- Player can't move into enemy positions (handled separately)
    return cell ~= 'enemy'
end

function PlayerSystem:movePlayer(player, newX, newY, grid)
    local currentCell = grid:getCell(player.x, player.y)
    local targetCell = grid:getCell(newX, newY)
    
    -- Determine if we're starting to draw a trail
    if targetCell == 'empty' and not player.isDrawing then
        player.isDrawing = true
        player.trail = {}
        -- Add current position as start of trail
        table.insert(player.trail, {x = player.x, y = player.y})
    end
    
    -- If drawing and moving to empty space, extend trail
    if player.isDrawing and targetCell == 'empty' then
        table.insert(player.trail, {x = player.x, y = player.y})
        grid:setCell(player.x, player.y, 'trail')
    end
    
    -- If drawing and returning to safe area, complete the shape
    if player.isDrawing and (targetCell == 'claimed' or targetCell == 'island') then
        self:completeShape(player, grid)
    end
    
    -- Move player
    player.x = newX
    player.y = newY
    
    -- Mark new position appropriately
    if not player.isDrawing then
        -- Player is in safe territory
        if grid:getCell(newX, newY) == 'empty' then
            -- This shouldn't happen with proper validation, but handle it
            grid:setCell(newX, newY, 'claimed')
        end
    end
end

function PlayerSystem:completeShape(player, grid)
    if #player.trail < 3 then
        -- Too small to be a valid shape
        self:cancelShape(player, grid)
        return
    end
    
    -- Fill the enclosed area using flood fill
    local areaFilled = self:floodFillArea(player.trail, grid)
    
    if areaFilled > 0 then
        -- Award points based on area size
        local points = areaFilled * Config.gameplay.areaMultiplier
        player.score = player.score + points
        
        -- Bonus for completing shape quickly
        if #player.trail < 10 then
            player.score = player.score + Config.gameplay.speedBonus
        end
    end
    
    -- Convert trail to claimed territory
    for _, point in ipairs(player.trail) do
        grid:setCell(point.x, point.y, 'claimed')
    end
    
    -- Reset drawing state
    player.isDrawing = false
    player.trail = {}
end

function PlayerSystem:cancelShape(player, grid)
    -- Remove trail from grid
    for _, point in ipairs(player.trail) do
        grid:setCell(point.x, point.y, 'empty')
    end
    
    player.isDrawing = false
    player.trail = {}
end

function PlayerSystem:floodFillArea(trail, grid)
    if #trail < 3 then return 0 end
    
    -- Create a simplified polygon from the trail
    local polygon = {}
    for _, point in ipairs(trail) do
        table.insert(polygon, point.x)
        table.insert(polygon, point.y)
    end
    
    -- Find bounding box of the trail
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    
    for _, point in ipairs(trail) do
        minX = math.min(minX, point.x)
        maxX = math.max(maxX, point.x)
        minY = math.min(minY, point.y)
        maxY = math.max(maxY, point.y)
    end
    
    -- Flood fill enclosed area
    local filledCells = 0
    local toFill = {}
    
    -- Start from points inside the bounding box
    for x = minX, maxX do
        for y = minY, maxY do
            if grid:getCell(x, y) == 'empty' then
                -- Check if point is inside the polygon (simplified)
                if self:pointInPolygon(x, y, trail) then
                    table.insert(toFill, {x = x, y = y})
                end
            end
        end
    end
    
    -- Fill the cells
    for _, cell in ipairs(toFill) do
        grid:setCell(cell.x, cell.y, 'claimed')
        filledCells = filledCells + 1
    end
    
    return filledCells
end

function PlayerSystem:pointInPolygon(x, y, polygon)
    local inside = false
    local j = #polygon
    
    for i = 1, #polygon do
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y
        
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    
    return inside
end

function PlayerSystem:takeDamage(player)
    if player.invulnerable then
        return false
    end
    
    player.lives = player.lives - 1
    player.invulnerable = true
    player.invulnerabilityTimer = Config.player.invulnerabilityTime
    
    -- Cancel any active trail
    if player.isDrawing then
        -- Don't remove trail cells, just reset state
        player.isDrawing = false
        player.trail = {}
    end
    
    -- Reset position to safe area
    player.x = 2
    player.y = 2
    
    return player.lives <= 0 -- Return true if game over
end

function PlayerSystem:draw(player, grid)
    local screenX = (player.x - 1) * Config.grid.cellSize
    local screenY = (player.y - 1) * Config.grid.cellSize
    local cellSize = Config.grid.cellSize
    
    -- Draw player with pulse animation
    if player.invulnerable then
        -- Flashing effect during invulnerability
        local flash = math.sin(player.invulnerabilityTimer * 10) > 0
        if flash then
            love.graphics.setColor(1, 1, 1, 0.7)
        else
            love.graphics.setColor(1, 1, 1, 0.3)
        end
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    -- Draw player as a diamond shape
    local centerX = screenX + cellSize / 2
    local centerY = screenY + cellSize / 2
    local size = (cellSize / 2 - 1) * player.pulseScale
    
    love.graphics.polygon("fill", {
        centerX, centerY - size,      -- top
        centerX + size, centerY,      -- right
        centerX, centerY + size,      -- bottom
        centerX - size, centerY       -- left
    })
    
    -- Draw trail preview if drawing
    if player.isDrawing and #player.trail > 0 then
        love.graphics.setColor(1, 1, 0, 0.8)
        love.graphics.setLineWidth(Config.player.trailWidth)
        
        -- Draw lines connecting trail points
        for i = 1, #player.trail - 1 do
            local p1 = player.trail[i]
            local p2 = player.trail[i + 1]
            love.graphics.line(
                (p1.x - 1) * cellSize + cellSize / 2,
                (p1.y - 1) * cellSize + cellSize / 2,
                (p2.x - 1) * cellSize + cellSize / 2,
                (p2.y - 1) * cellSize + cellSize / 2
            )
        end
        
        -- Draw line from last trail point to current position
        if #player.trail > 0 then
            local lastPoint = player.trail[#player.trail]
            love.graphics.line(
                (lastPoint.x - 1) * cellSize + cellSize / 2,
                (lastPoint.y - 1) * cellSize + cellSize / 2,
                centerX, centerY
            )
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return PlayerSystem
