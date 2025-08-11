-- src/game.lua  
-- Territory capture game state integrating existing Player and Grid systems

local love = require "love"
local Gamestate = require 'hump.gamestate'

local Game = {}

-- Core Systems
local Grid = require 'src.grid'
local Player = require 'src.player'
local Config = require 'src.config'

-- Shape Drawing Systems
local ShapeTemplates = require 'src.systems.shape_templates'
local DrawPathSystem = require 'src.systems.draw_path_system'
local ShapeMatcher = require 'src.systems.shape_matcher'
local ShapeScore = require 'src.systems.shape_score'

-- Game State
local gameTime = 0
local level = 1
local score = 0
local shapeScore = 0
local targetPercentage = 75 -- Win condition: capture 75% of territory
local gameOver = false
local gameWon = false
local livesRemaining = 3
local enemySpawnTimer = 0
local enemySpawnDelay = 3.0
local Enemies = {}

-- Shape Challenge State
local currentShapeTemplate = nil
local shapeChallenge = {
    active = false,
    completed = false,
    showPreview = true,
    previewTimer = 3.0, -- Show template for 3 seconds
    result = nil
}

-- Character Selection
if not _G.selectedCharacter then
    _G.selectedCharacter = {name = "Architect", speed = 1.0}
end

function Game:enter(...)
    print("Game:enter() - Starting new game")
    self:initializeGame()
end

function Game:initializeGame()
    print("Game:initializeGame() called")
    
    -- Reset game state
    gameTime = 0
    score = 0
    shapeScore = 0
    gameOver = false
    gameWon = false
    livesRemaining = 3
    enemySpawnTimer = 0
    Enemies = {}
    
    -- Initialize grid with reduced cell size
    local screenWidth, screenHeight = love.graphics.getDimensions()
    Grid:setSizeToWindow(screenWidth, screenHeight, 5) -- Reduced from 50 to 5 (90% reduction)
    Grid:load()
    
    -- Set up callback for when territory is claimed
    Grid.onTerritoryClaimed = function()
        self:relocateEnemiesFromClaimedTerritory()
        self:checkTerritoryScoring() -- Check for false scoring
    end
    
    print("Grid initialized:", Grid.width, "x", Grid.height, "cells")
    
    -- Initialize shape systems
    ShapeTemplates:init()
    DrawPathSystem:init()
    ShapeMatcher:init()
    ShapeScore:init()
    
    -- Initialize player with grid-based movement
    Player:load(Grid, _G.selectedCharacter)
    print("Player initialized at grid position:", Player.i, Player.j)
    
    -- Initialize shape challenge for this level
    self:initializeShapeChallenge()
    
    -- Spawn initial enemies based on level
    self:spawnEnemiesForLevel()
    
    print("Game initialized - Level", level, "Target:", targetPercentage .. "%")
    if currentShapeTemplate then
        print("Shape challenge:", currentShapeTemplate.name, "- Difficulty:", currentShapeTemplate.difficulty)
    end
end

function Game:initializeShapeChallenge()
    -- Get shape template for current level
    currentShapeTemplate = ShapeTemplates:getShapeForLevel(level)
    
    if currentShapeTemplate then
        -- Convert template to grid coordinates
        local gridTemplate = ShapeTemplates:convertToGridCoords(
            currentShapeTemplate, 
            Grid.width, 
            Grid.height, 
            Grid.offsetX or 0, 
            Grid.offsetY or 0
        )
        currentShapeTemplate = gridTemplate
        
        -- Reset shape challenge state
        shapeChallenge.active = true
        shapeChallenge.completed = false
        shapeChallenge.showPreview = true
        shapeChallenge.previewTimer = 3.0
        shapeChallenge.result = nil
        
        print("Shape challenge initialized:", currentShapeTemplate.name)
    end
end

function Game:checkTerritoryScoring()
    -- Fix: Only award points for actual territory capture via proper loop closure
    -- This prevents the bug where walking in claimed territory increases score
    local currentClaimedPercent = Grid:getClaimedPercent() * 100
    
    -- Territory scoring should only happen via proper shape closure, not walking
    -- The score will be calculated in the shape system when shapes are completed
    print("Territory check - Current claimed:", math.floor(currentClaimedPercent) .. "%")
end

function Game:spawnEnemiesForLevel()
    local enemyCount = math.min(2 + level, 6) -- Start with 2-3 enemies, max 6
    
    for i = 1, enemyCount do
        local enemy = self:createSimpleEnemy()
        if enemy then
            table.insert(Enemies, enemy)
        end
    end
    
    -- Clean up any enemies that might be in claimed territory
    self:relocateEnemiesFromClaimedTerritory()
    
    print("Spawned", #Enemies, "enemies for level", level)
end

function Game:relocateEnemiesFromClaimedTerritory()
    -- Move any enemies that are in claimed territory to unclaimed areas
    for i = #Enemies, 1, -1 do
        local enemy = Enemies[i]
        if Grid:isClaimed(enemy.i, enemy.j) then
            -- Find a new unclaimed position
            local newPos = self:findUnclaimedPosition()
            if newPos then
                enemy.i = newPos.i
                enemy.j = newPos.j
                print("Relocated enemy from claimed territory to", newPos.i, newPos.j)
            else
                -- If no unclaimed positions available, remove this enemy
                table.remove(Enemies, i)
                print("Removed enemy from claimed territory - no unclaimed positions available")
            end
        end
    end
end

function Game:findUnclaimedPosition()
    local unclaimedPositions = {}
    for i = 2, Grid.width - 1 do
        for j = 2, Grid.height - 1 do
            if not Grid:isClaimed(i, j) then
                table.insert(unclaimedPositions, {i = i, j = j})
            end
        end
    end
    
    if #unclaimedPositions > 0 then
        return unclaimedPositions[math.random(1, #unclaimedPositions)]
    end
    return nil
end

function Game:createSimpleEnemy()
    -- Create a simple enemy with basic AI
    local enemy = {
        i = 5,
        j = 5,
        moveTimer = 0,
        moveDelay = 0.5 + math.random() * 0.3,
        lastDirection = {x = 0, y = 0}
    }
    
    -- Place enemy at random UNCLAIMED position (enemies should not be in claimed territory)
    -- Also avoid spawning too close to player start position
    local safePositions = {}
    local playerStartArea = {i = 1, j = math.floor(Grid.nodeHeight / 2)}
    
    for i = 2, Grid.width - 1 do
        for j = 2, Grid.height - 1 do
            if not Grid:isClaimed(i, j) then -- Fixed: enemies spawn in unclaimed areas
                -- Don't spawn too close to player start position
                local distFromPlayerStart = math.abs(i - playerStartArea.i) + math.abs(j - playerStartArea.j)
                if distFromPlayerStart > 3 then -- Keep at least 3 cells away from player start
                    table.insert(safePositions, {i = i, j = j})
                end
            end
        end
    end
    
    if #safePositions > 0 then
        local pos = safePositions[math.random(1, #safePositions)]
        enemy.i = pos.i
        enemy.j = pos.j
        return enemy
    end
    
    return nil
end

function Game:updateEnemy(enemy, dt)
    enemy.moveTimer = enemy.moveTimer + dt
    if enemy.moveTimer >= enemy.moveDelay then
        enemy.moveTimer = 0
        
        -- Simple AI: move randomly but prefer continuing in same direction
        local directions = {{-1,0}, {1,0}, {0,-1}, {0,1}}
        local chosenDir = nil
        
        -- 60% chance to continue in same direction if possible
        if enemy.lastDirection.x ~= 0 or enemy.lastDirection.y ~= 0 then
            local continueI = enemy.i + enemy.lastDirection.x
            local continueJ = enemy.j + enemy.lastDirection.y
            if Grid:isInside(continueI, continueJ) and not Grid:isClaimed(continueI, continueJ) then -- Fixed: stay in unclaimed areas
                if math.random() < 0.6 then
                    chosenDir = enemy.lastDirection
                end
            end
        end
        
        -- Otherwise pick a random valid direction
        if not chosenDir then
            local validDirs = {}
            for _, dir in ipairs(directions) do
                local newI = enemy.i + dir[1]
                local newJ = enemy.j + dir[2]
                if Grid:isInside(newI, newJ) and not Grid:isClaimed(newI, newJ) then -- Fixed: move to unclaimed areas only
                    table.insert(validDirs, {x = dir[1], y = dir[2]})
                end
            end
            
            if #validDirs > 0 then
                chosenDir = validDirs[math.random(1, #validDirs)]
            end
        end
        
        -- Move enemy
        if chosenDir then
            enemy.i = enemy.i + chosenDir.x
            enemy.j = enemy.j + chosenDir.y
            enemy.lastDirection = chosenDir
        end
    end
end

function Game:update(dt)
    if gameOver or gameWon then return end
    
    gameTime = gameTime + dt
    
    -- Update shape challenge preview timer
    if shapeChallenge.showPreview and shapeChallenge.previewTimer > 0 then
        shapeChallenge.previewTimer = shapeChallenge.previewTimer - dt
        if shapeChallenge.previewTimer <= 0 then
            shapeChallenge.showPreview = false
        end
    end
    
    -- Update grid
    Grid:update(dt)
    
    -- Update player (this handles the sophisticated grid-based movement)
    Player:update(dt, Grid)
    
    -- Update shape drawing system
    self:updateShapeDrawing(dt)
    
    -- Update enemies
    for i = #Enemies, 1, -1 do
        local enemy = Enemies[i]
        self:updateEnemy(enemy, dt)
        
        -- Safety check: if enemy somehow ended up in claimed territory, relocate it
        if Grid:isClaimed(enemy.i, enemy.j) then
            local newPos = self:findUnclaimedPosition()
            if newPos then
                enemy.i = newPos.i
                enemy.j = newPos.j
            else
                -- Remove enemy if no unclaimed positions available
                table.remove(Enemies, i)
            end
        end
        
        -- Only check collisions if enemy still exists
        if i <= #Enemies then
            local enemy = Enemies[i]
            
            -- Check collision with player
            if enemy.i == Player.i and enemy.j == Player.j then
                self:handlePlayerEnemyCollision()
                break
            end
            
            -- Check if enemy hit player trail (both regular trail and shape drawing)
            if Player.isDrawing or DrawPathSystem.isDrawing then
                for _, trailNode in ipairs(Player.trail or {}) do
                    if enemy.i == trailNode.i and enemy.j == trailNode.j then
                        self:handleTrailHit()
                        break
                    end
                end
            end
                        break
                    end
                end
            end
        end
    end
    
    -- Spawn more enemies periodically
    enemySpawnTimer = enemySpawnTimer + dt
    if enemySpawnTimer >= enemySpawnDelay then
        enemySpawnTimer = 0
        enemySpawnDelay = math.max(2.0, enemySpawnDelay - 0.1) -- Spawn faster over time
        
        if #Enemies < 8 then -- Max enemy cap
            local enemy = self:createSimpleEnemy()
            if enemy then
                table.insert(Enemies, enemy)
            end
        end
    end
    
    -- Check win condition (both territory and shape completion)
    local claimedPercent = Grid:getClaimedPercent() * 100
    local territoryComplete = claimedPercent >= targetPercentage
    local shapeComplete = shapeChallenge.completed
    
    if territoryComplete and (shapeComplete or not shapeChallenge.active) then
        self:handleLevelComplete()
    end
end

function Game:updateShapeDrawing(dt)
    if not shapeChallenge.active or shapeChallenge.completed then return end
    
    -- Check if player is outside claimed territory (shape drawing zone)
    local playerInClaimedTerritory = Grid:isClaimed(Player.i, Player.j)
    
    -- Start shape drawing when player leaves claimed territory
    if not DrawPathSystem.isDrawing and not playerInClaimedTerritory and Player.isDrawing then
        DrawPathSystem:startDrawing(Player.i, Player.j)
    end
    
    -- Add points to shape path while drawing outside claimed territory
    if DrawPathSystem.isDrawing and not playerInClaimedTerritory then
        DrawPathSystem:addPoint(Player.i, Player.j)
    end
    
    -- Complete shape drawing when player returns to claimed territory or closes loop
    if DrawPathSystem.isDrawing and (playerInClaimedTerritory or self:isPlayerTrailClosed()) then
        local drawData = DrawPathSystem:finishDrawing()
        if drawData then
            self:evaluateShapeDrawing(drawData)
        end
    end
    
    -- Cancel shape drawing if player stops drawing trail
    if DrawPathSystem.isDrawing and not Player.isDrawing then
        DrawPathSystem:cancelDrawing()
    end
end

function Game:isPlayerTrailClosed()
    if not Player.trail or #Player.trail < 3 then return false end
    
    local firstPoint = Player.trail[1]
    local lastPoint = Player.trail[#Player.trail]
    
    -- Check if last point is close to first point (closed loop)
    local distance = math.abs(firstPoint.i - lastPoint.i) + math.abs(firstPoint.j - lastPoint.j)
    return distance <= 1
end

function Game:evaluateShapeDrawing(drawData)
    if not currentShapeTemplate or not drawData then return end
    
    -- Count nearby enemies for risk bonus
    local nearbyEnemies = 0
    for _, enemy in ipairs(Enemies) do
        local distance = math.abs(enemy.i - Player.i) + math.abs(enemy.j - Player.j)
        if distance <= 5 then -- Within 5 grid cells
            nearbyEnemies = nearbyEnemies + 1
        end
    end
    
    -- Create game context for scoring
    local gameContext = {
        template = currentShapeTemplate,
        enemiesNearby = nearbyEnemies,
        level = level
    }
    
    -- Match the drawn shape to the template
    local matchResult = ShapeMatcher:matchShape(drawData, currentShapeTemplate)
    
    -- Calculate score
    local scoreResult = ShapeScore:calculateShapeScore(matchResult, drawData, gameContext)
    
    -- Update game state
    shapeChallenge.result = scoreResult
    shapeChallenge.completed = true
    shapeScore = shapeScore + scoreResult.totalScore
    
    print("Shape drawing completed!")
    print("Accuracy:", math.floor(matchResult.accuracy * 100) .. "%")
    print("Grade:", scoreResult.grade)
    print("Score:", scoreResult.totalScore)
    
    -- Visual/audio feedback
    self:showShapeResult(scoreResult)
end

function Game:showShapeResult(scoreResult)
    -- This will be called to show the shape result UI
    -- For now, just print the result
    local display = ShapeScore:getScoreDisplay(scoreResult)
    print("Shape Result:", display.title, "- Score:", scoreResult.totalScore)
end
    end
end

function Game:handlePlayerEnemyCollision()
    print("Player hit by enemy!")
    
    if Player.isDrawing then
        -- Cancel current trail
        Player:cancelTrail(Grid)
        print("Trail cancelled due to enemy collision")
    else
        -- Player is in safe zone, lose a life
        livesRemaining = livesRemaining - 1
        print("Life lost! Lives remaining:", livesRemaining)
        
        if livesRemaining <= 0 then
            self:handleGameOver()
        else
            -- Respawn player at safe position
            Player.i = 1
            Player.j = math.floor(Grid.nodeHeight / 2)
        end
    end
end

function Game:handleTrailHit()
    print("Enemy hit player trail!")
    Player:cancelTrail(Grid)
end

function Game:handleLevelComplete()
    gameWon = true
    score = score + 1000 + (level * 500)
    print("Level", level, "complete! Score:", score)
    
    -- Brief pause then advance
    love.timer.sleep(0.5)
    self:advanceLevel()
end

function Game:advanceLevel()
    level = level + 1
    targetPercentage = math.min(85, targetPercentage + 3) -- Increase difficulty
    
    -- Reset for next level but keep some progress
    local keepPercent = 0.4 -- Keep 40% of claimed territory
    Grid:resetPartial(keepPercent)
    
    -- Reset player
    Player.i = 1  
    Player.j = math.floor(Grid.nodeHeight / 2)
    Player.trail = {}
    Player.isDrawing = false
    
    -- Clear enemies and spawn new ones
    Enemies = {}
    enemySpawnDelay = math.max(1.5, 3.0 - level * 0.2) -- Faster spawning
    self:spawnEnemiesForLevel()
    
    gameWon = false
    print("Advanced to level", level, "- New target:", targetPercentage .. "%")
end

function Game:handleGameOver()
    gameOver = true
    print("Game Over! Final Score:", score)
end

function Game:draw()
    -- Draw grid (includes territory and trails)
    Grid:draw()
    
    -- Draw shape template if shape challenge is active
    if self.shapeChallenge and self.shapeChallenge.active then
        self:drawShapeTemplate()
    end
    
    -- Draw player's drawing path
    if DrawPathSystem and DrawPathSystem.getCurrentPath then
        self:drawShapePath()
    end
    
    -- Draw enemies
    for _, enemy in ipairs(Enemies) do
        local x = Grid.offsetX + (enemy.i - 1) * Grid.cellSize + Grid.cellSize/2
        local y = Grid.offsetY + (enemy.j - 1) * Grid.cellSize + Grid.cellSize/2
        love.graphics.setColor(0.9, 0.2, 0.2, 1) -- Red
        love.graphics.circle("fill", x, y, Grid.cellSize/3)
    end
    
    -- Draw player (use existing Player system if available)
    if Player.draw then
        Player:draw(Grid)
    else
        -- Fallback player rendering
        local x = Grid.offsetX + (Player.i - 1) * Grid.cellSize + Grid.cellSize/2  
        local y = Grid.offsetY + (Player.j - 1) * Grid.cellSize + Grid.cellSize/2
        love.graphics.setColor(1, 1, 1, 1) -- White
        love.graphics.circle("fill", x, y, Grid.cellSize/2)
    end
    
    -- Draw UI
    self:drawUI()
    
    -- Draw shape challenge UI if active
    if self.shapeChallenge and self.shapeChallenge.active then
        self:drawShapeChallengeUI()
    end
    
    -- Draw game over/win screen
    if gameOver then
        self:drawGameOverScreen()
    elseif gameWon then
        self:drawLevelCompleteScreen()
    end
end

function Game:drawUI()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Level: " .. level, 10, 10)
    love.graphics.print("Territory Score: " .. score, 10, 30) 
    love.graphics.print("Shape Score: " .. shapeScore, 10, 50)
    love.graphics.print("Total Score: " .. (score + shapeScore), 10, 70)
    love.graphics.print("Lives: " .. livesRemaining, 10, 90)
    
    local claimedPercent = math.floor(Grid:getClaimedPercent() * 100)
    love.graphics.print("Territory: " .. claimedPercent .. "% / " .. targetPercentage .. "%", 10, 110)
    
    love.graphics.print("Enemies: " .. #Enemies, 10, 130)
    love.graphics.print("Time: " .. math.floor(gameTime), 10, 150)
    
    -- Character info
    if Player.character then
        love.graphics.print("Character: " .. Player.character.name, 10, 170)
    end
    
    -- Game status
    if Player.isDrawing then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print("CAPTURING TERRITORY...", 10, 150)
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    -- Controls
    love.graphics.print("WASD: Move | ESC: Menu | R: Restart", 10, love.graphics.getHeight() - 40)
end

function Game:drawGameOverScreen()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Game Over text
    love.graphics.setColor(1, 0.2, 0.2, 1)
    love.graphics.printf("GAME OVER", 0, screenHeight/2 - 40, screenWidth, "center")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Final Score: " .. score, 0, screenHeight/2, screenWidth, "center")
    love.graphics.printf("Press R to restart or ESC for menu", 0, screenHeight/2 + 40, screenWidth, "center")
end

function Game:drawShapeTemplate()
    if not self.shapeChallenge or not self.shapeChallenge.currentTemplate then
        return
    end
    
    local template = self.shapeChallenge.currentTemplate
    love.graphics.setColor(0.5, 0.8, 1, 0.3) -- Light blue, semi-transparent
    love.graphics.setLineWidth(2)
    
    -- Draw template outline
    if template.points and #template.points > 2 then
        for i = 1, #template.points - 1 do
            local p1 = template.points[i]
            local p2 = template.points[i + 1]
            local x1 = Grid.offsetX + p1.i * Grid.cellSize
            local y1 = Grid.offsetY + p1.j * Grid.cellSize
            local x2 = Grid.offsetX + p2.i * Grid.cellSize
            local y2 = Grid.offsetY + p2.j * Grid.cellSize
            love.graphics.line(x1, y1, x2, y2)
        end
        
        -- Close the shape if specified
        if template.closed then
            local first = template.points[1]
            local last = template.points[#template.points]
            local x1 = Grid.offsetX + first.i * Grid.cellSize
            local y1 = Grid.offsetY + first.j * Grid.cellSize
            local x2 = Grid.offsetX + last.i * Grid.cellSize
            local y2 = Grid.offsetY + last.j * Grid.cellSize
            love.graphics.line(x1, y1, x2, y2)
        end
    end
    
    love.graphics.setLineWidth(1) -- Reset line width
end

function Game:drawShapePath()
    local currentPath = DrawPathSystem.getCurrentPath()
    if not currentPath or #currentPath < 2 then
        return
    end
    
    love.graphics.setColor(1, 1, 0, 0.8) -- Yellow, semi-transparent
    love.graphics.setLineWidth(3)
    
    -- Draw the path lines
    for i = 1, #currentPath - 1 do
        local p1 = currentPath[i]
        local p2 = currentPath[i + 1]
        local x1 = Grid.offsetX + p1.i * Grid.cellSize
        local y1 = Grid.offsetY + p1.j * Grid.cellSize
        local x2 = Grid.offsetX + p2.i * Grid.cellSize
        local y2 = Grid.offsetY + p2.j * Grid.cellSize
        love.graphics.line(x1, y1, x2, y2)
    end
    
    love.graphics.setLineWidth(1) -- Reset line width
end

function Game:drawShapeChallengeUI()
    if not self.shapeChallenge or not self.shapeChallenge.active then
        return
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    local screenWidth = love.graphics.getWidth()
    
    -- Draw challenge info
    love.graphics.print("Shape Challenge: " .. (self.shapeChallenge.currentTemplate.name or "Unknown"), screenWidth - 250, 10)
    
    -- Draw time remaining if there's a time limit
    if self.shapeChallenge.timeRemaining and self.shapeChallenge.timeRemaining > 0 then
        love.graphics.print("Time: " .. math.ceil(self.shapeChallenge.timeRemaining), screenWidth - 250, 30)
    end
    
    -- Draw progress/feedback
    if self.shapeChallenge.feedback then
        love.graphics.setColor(0.2, 1, 0.2, 1) -- Green for feedback
        love.graphics.print(self.shapeChallenge.feedback, screenWidth - 250, 50)
    end
end

function Game:drawLevelCompleteScreen()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Overlay
    love.graphics.setColor(0, 0.2, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Level Complete text
    love.graphics.setColor(0.2, 1, 0.2, 1)
    love.graphics.printf("LEVEL " .. (level-1) .. " COMPLETE!", 0, screenHeight/2 - 40, screenWidth, "center")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Score: " .. score, 0, screenHeight/2, screenWidth, "center")
    love.graphics.printf("Advancing to Level " .. level .. "...", 0, screenHeight/2 + 40, screenWidth, "center")
end

function Game:keypressed(key)
    if key == "escape" then
        local Menu = require 'src.ui.menu'
        Gamestate.switch(Menu)
    elseif key == "r" and gameOver then
        level = 1
        score = 0
        self:initializeGame()
    end
end

function Game:resize(w, h)
    Grid:setSizeToWindow(w, h, 50)
end

return Game
