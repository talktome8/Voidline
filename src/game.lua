-- src/game.lua  
-- Territory capture game state integrating existing Player and Grid systems

local love = require "love"
local Gamestate = require 'hump.gamestate'

local Game = {}
local ok_cfg, Config = pcall(require, 'src.config')

-- Core Systems
local Grid = require 'src.grid'
local Player = require 'src.player'
local Config = require 'src.config'

-- Shape Drawing Systems
local ShapeTemplates = require 'src.systems.shape_templates'
local DrawPathSystem = require 'src.systems.draw_path_system'
-- Safe no-op fallback if require fails (defensive)
if not DrawPathSystem then
    DrawPathSystem = { new=function()
        return { reset=function()end, startPath=function()end, addPoint=function()end, finishPath=function()end, update=function()end, draw=function()end }
    end }
end
local ShapeMatcher = require 'src.systems.shape_matcher'
local ShapeScore = require 'src.systems.shape_score'
local ShapeFeedback = require 'src.systems.shape_feedback'
local ShapePanel = require 'src.ui.shape_panel'
local IngameHUD = require 'src.ui.ingame_hud'

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
-- UI toast for quick messages
local toast = { msg = nil, timer = 0 }

-- Shape Challenge State
local currentShapeTemplate = nil
local targetShapeId = nil
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
_G.currentLevel = level

function Game:enter(...)
    if ok_cfg and Config.debug and Config.debug.enabled then print("Game:enter() - Starting new game") end
    self:initializeGame()
end

function Game:initializeGame()
    if ok_cfg and Config.debug and Config.debug.enabled then print("Game:initializeGame() called") end
    
    -- Reset game state
    gameTime = 0
    score = 0
    shapeScore = 0
    gameOver = false
    gameWon = false
    livesRemaining = 3
    enemySpawnTimer = 0
    Enemies = {}
    -- Use panel-only HUD by default (hide top-center overlays)
    self.minimalHUD = true
    
    -- Initialize grid with reduced cell size and reserve right panel space
    local screenWidth, screenHeight = love.graphics.getDimensions()
    -- Responsive right pane width (panel area)
    local rightPanePx = math.floor(math.max(260, math.min(380, 0.22 * screenWidth)))
    Grid:setSizeToWindow(screenWidth, screenHeight, 16, rightPanePx)
    Grid:load()
    -- Set required territory percent per level for HUD
    Grid:setRequiredClaimedPercent(self:getRequiredTerritoryForLevel(level) / 100)
    
    -- Set up callback for when territory is claimed
    Grid.onTerritoryClaimed = function()
        self:relocateEnemiesFromClaimedTerritory()
        self:checkTerritoryScoring() -- Check for false scoring
        -- After area closure and fill, process captured enemies and rewards
        if self.onAreaClosed then self:onAreaClosed() end
    end
    
    if ok_cfg and Config.debug and Config.debug.enabled then print("Grid initialized:", Grid.width, "x", Grid.height, "cells") end
    
    -- Initialize shape systems (only those that have init methods)
    -- Instance-based draw path system
    self.drawPath = DrawPathSystem:new()
    self.drawPath.grid = Grid
    self.drawPath:reset()
    ShapeMatcher:init()
    ShapeScore.init(ShapeScore)  -- Use dot notation for module method
    ShapeFeedback:init() -- Initialize the new feedback system
    
    -- ShapeTemplates is a static module, no init needed
    if ok_cfg and Config.debug and Config.debug.enabled then print("Shape systems initialized") end
    
    -- Initialize player with grid-based movement
    Player:load(Grid, _G.selectedCharacter)
    if ok_cfg and Config.debug and Config.debug.enabled then print("Player initialized at grid position:", Player.i, Player.j) end
    
    -- Initialize shape challenge for this level
    self:initializeShapeChallenge()

    -- Initialize shape panel (top-right), anchor within right pane
    local panelW = 220
    local panelH = 240
    local panelX = screenWidth - (math.max(260, math.min(380, 0.22 * screenWidth))) + 10
    self.shapePanel = ShapePanel:new({ x = panelX, y = 16, w = panelW, h = panelH })
    if currentShapeTemplate then
        self.shapePanel:setTemplate(currentShapeTemplate.name, currentShapeTemplate.points, currentShapeTemplate.requiredAccuracy or 80)
    end

    -- Combo tracking for repeated shapes
    self._shapeCombo = self._shapeCombo or {}
    self._lastShapeName = nil
    self._comboMultiplier = 1.0
    
    -- Spawn initial enemies based on level
    self:spawnEnemiesForLevel()
    
    if ok_cfg and Config.debug and Config.debug.enabled then print("Game initialized - Level", level, "Target:", targetPercentage .. "%") end
    if currentShapeTemplate then
    if ok_cfg and Config.debug and Config.debug.enabled then print("Shape challenge:", currentShapeTemplate.name, "- Difficulty:", currentShapeTemplate.difficulty) end
    end
end

function Game:initializeShapeChallenge()
    -- Get shape template for current level
    currentShapeTemplate = ShapeTemplates:getShapeForLevel(level)
    targetShapeId = currentShapeTemplate and currentShapeTemplate.name or nil
    
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
        
    -- Reset feedback system for new level
    ShapeFeedback:reset()
    ShapeFeedback:setStars(0)
        -- Update UI panel template
        if self.shapePanel then
            self.shapePanel:setTemplate(currentShapeTemplate.name, currentShapeTemplate.points, currentShapeTemplate.requiredAccuracy or self:getRequiredAccuracyForLevel(level))
        end
        
        if ok_cfg and Config.debug and Config.debug.enabled then
            print("Shape challenge initialized:", currentShapeTemplate.name)
        end
    end
end

function Game:checkTerritoryScoring()
    -- Fix: Only award points for actual territory capture via proper loop closure
    -- This prevents the bug where walking in claimed territory increases score
    local currentClaimedPercent = Grid:getClaimedPercent() * 100
    
    -- Territory scoring should only happen via proper shape closure, not walking
    -- The score will be calculated in the shape system when shapes are completed
    if ok_cfg and Config.debug and Config.debug.enabled then print("Territory check - Current claimed:", math.floor(currentClaimedPercent) .. "%") end
end

function Game:spawnEnemiesForLevel()
    local enemyCount = math.min(2 + level, 8)
    local isBossLevel = (level % 5 == 0)

    for i = 1, enemyCount do
        local enemy = self:createSimpleEnemy()
        if enemy then
            -- Scale enemy move frequency with level (faster on higher levels)
            enemy.moveDelay = math.max(0.18, (enemy.moveDelay or 0.5) - (level - 1) * 0.02)
            table.insert(Enemies, enemy)
        end
    end

    if isBossLevel then
        local boss = self:createSimpleEnemy()
        if boss then
            boss.isBoss = true
            boss.health = 3
            boss.moveDelay = math.max(0.22, 0.5 - (level - 1) * 0.01)
            table.insert(Enemies, boss)
        end
    end

    -- Clean up any enemies that might be in claimed territory
    self:relocateEnemiesFromClaimedTerritory()

    if ok_cfg and Config.debug and Config.debug.enabled then print("Spawned", #Enemies, "enemies for level", level, isBossLevel and "(Boss present)" or "") end
end

-- After a successful area closure and flood fill, remove captured enemies and apply rewards
function Game:onAreaClosed()
    local captured = 0
    for idx = #Enemies, 1, -1 do
        local e = Enemies[idx]
        if Grid:isClaimed(e.i, e.j) then
            captured = captured + 1
            if e.isBoss then
                livesRemaining = (livesRemaining or 0) + 1
                if ok_cfg and Config.debug and Config.debug.enabled then print("Boss captured: +1 life (" .. tostring(livesRemaining) .. ")") end
            end
            table.remove(Enemies, idx)
        end
    end
    if captured > 0 then
        local bonus = captured * 100
        score = score + bonus
    if ok_cfg and Config.debug and Config.debug.enabled then print("Captured " .. captured .. " enemies inside area (+" .. bonus .. ")") end
    end
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
                if ok_cfg and Config.debug and Config.debug.enabled then print("Relocated enemy from claimed territory to", newPos.i, newPos.j) end
            else
                -- If no unclaimed positions available, remove this enemy
                table.remove(Enemies, i)
                if ok_cfg and Config.debug and Config.debug.enabled then print("Removed enemy from claimed territory - no unclaimed positions available") end
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
        
        -- Move enemy with small telegraph (store last position and fade timer)
        if chosenDir then
            enemy.prevI, enemy.prevJ = enemy.i, enemy.j
            enemy.telegraphTimer = 0.15
            enemy.i = enemy.i + chosenDir.x
            enemy.j = enemy.j + chosenDir.y
            enemy.lastDirection = chosenDir
        end
    end
    -- Decay telegraph timer
    if enemy.telegraphTimer then
        enemy.telegraphTimer = enemy.telegraphTimer - dt
        if enemy.telegraphTimer <= 0 then enemy.telegraphTimer = nil end
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
    -- Update instance draw path animations if any
    if self.drawPath and self.drawPath.update then self.drawPath:update(dt) end
    -- Update shape panel
    if self.shapePanel then self.shapePanel:update(dt) end
    
    -- Update shape feedback system
    ShapeFeedback:update(dt)
    
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
            local onOuterBorder = (Player.i == 1 or Player.i == Grid.nodeWidth or Player.j == 1 or Player.j == Grid.nodeHeight)
            if enemy.i == Player.i and enemy.j == Player.j and not onOuterBorder then
                self:handlePlayerEnemyCollision()
                break
            end
            
            -- Check if enemy hit player trail (both regular trail and shape drawing)
            if Player.isDrawing then
                for _, trailNode in ipairs(Player.trail or {}) do
                    if enemy.i == trailNode.i and enemy.j == trailNode.j then
                        if onOuterBorder then break end -- ignore hits while player is on border
                        self:handleTrailHit()
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

    -- Update toast timer
    if toast.timer and toast.timer > 0 then
        toast.timer = toast.timer - dt
        if toast.timer <= 0 then
            toast.timer = 0
            toast.msg = nil
        end
    end
    
    -- Handle delayed level completion from target shape success
    if self._levelCompletionDelay and self._levelCompletionDelay > 0 then
        self._levelCompletionDelay = self._levelCompletionDelay - dt
        if self._levelCompletionDelay <= 0 then
            self._levelCompletionDelay = nil
            self:handleLevelComplete()
            return -- Skip other updates during transition
        end
    end
    
    -- Check win condition (both territory and shape completion per rules)
    local claimedPercent = Grid:getClaimedPercent() * 100
    local requiredTerr = self:getRequiredTerritoryForLevel(level)
    local requiredAcc = self:getRequiredAccuracyForLevel(level)
    local territoryComplete = claimedPercent >= requiredTerr
    local accuracyPct = (self.shapeAccuracy or 0)
    local shapeOK = (accuracyPct >= requiredAcc) and (currentShapeTemplate and currentShapeTemplate.name == targetShapeId)
    if territoryComplete and shapeOK then self:handleLevelComplete() end
end

function Game:updateShapeDrawing(dt)
    if not shapeChallenge.active or shapeChallenge.completed then return end
    
    -- Check if player is outside claimed territory (shape drawing zone)
    local playerInClaimedTerritory = Grid:isClaimed(Player.i, Player.j)
    
    -- The Player feeds pixel points directly to self.drawPath; here we only finish/evaluate if needed
    -- If a finish just happened, the Player already called finishPath; we can evaluate based on returned data
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
    -- Rule: at least one vertex touches claimed or border (safe area)
    local function touchesSafe()
        if not drawData.points or #drawData.points == 0 then return false end
        for _, pt in ipairs(drawData.points) do
            -- Convert pixel to nearest node indices
            local ni = math.floor((pt.x - Grid.offsetX) / Grid.cellSize + 0.5) + 1
            local nj = math.floor((pt.y - Grid.offsetY) / Grid.cellSize + 0.5) + 1
            -- Clamp
            ni = math.max(1, math.min(Grid.nodeWidth, ni))
            nj = math.max(1, math.min(Grid.nodeHeight, nj))
            -- Border nodes are safe, or adjacent claimed cells
            if ni == 1 or nj == 1 or ni == Grid.nodeWidth or nj == Grid.nodeHeight then
                return true
            end
            local ci = math.min(ni, Grid.width)
            local cj = math.min(nj, Grid.height)
            if Grid:isClaimed(ci, cj) then return true end
            -- Check 4-neighborhood for claimed
            if Grid:isClaimed(ci-1, cj) or Grid:isClaimed(ci+1, cj) or Grid:isClaimed(ci, cj-1) or Grid:isClaimed(ci, cj+1) then
                return true
            end
        end
        return false
    end
    if not touchesSafe() then
        -- Post a brief warning and ignore this attempt
        Player.failedClosureWarning = 1.8
    if ok_cfg and Config.debug and Config.debug.enabled then print("Closure invalid: finish on safe area (border or claimed) required") end
        return
    end
    
    -- ENHANCED: Strict validation to prevent false shape success
    local function isValidShape()
        -- Minimum complexity check
        if not drawData.points or #drawData.points < 4 then
            if ok_cfg and Config.debug and Config.debug.enabled then print("Shape too simple:", #(drawData.points or {}), "points (need 4+)") end
            return false
        end
        
        -- Must form a closed loop (start and end near each other)
        local firstPt = drawData.points[1]
        local lastPt = drawData.points[#drawData.points]
        if firstPt and lastPt then
            local distance = math.sqrt((firstPt.x - lastPt.x)^2 + (firstPt.y - lastPt.y)^2)
            if distance > Grid.cellSize * 3 then -- Allow some tolerance
                if ok_cfg and Config.debug and Config.debug.enabled then print("Shape not closed: distance", math.floor(distance), "(max", Grid.cellSize * 3, ")") end
                return false
            end
        end
        
        -- Must have meaningful area (not just a line)
        local minArea = Grid.cellSize * Grid.cellSize * 4  -- At least 4 cell areas
        if (drawData.boundingBox and drawData.boundingBox.width and drawData.boundingBox.height) then
            local area = drawData.boundingBox.width * drawData.boundingBox.height
            if area < minArea then
                if ok_cfg and Config.debug and Config.debug.enabled then print("Shape area too small:", math.floor(area), "(need", minArea, ")") end
                return false
            end
        end
        
        return true
    end
    
    if not isValidShape() then
        Player.failedClosureWarning = 1.8
        if ok_cfg and Config.debug and Config.debug.enabled then print("Shape validation failed - invalid shape drawn") end
        return
    end
    
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
    
    -- Calculate base score
    local scoreResult = ShapeScore:calculateShapeScore(matchResult, drawData, gameContext)

    -- Combo for repeating same shape consecutively
    local shapeName = currentShapeTemplate and currentShapeTemplate.name or "?"
    if self._lastShapeName == shapeName then
        local count = (self._shapeCombo[shapeName] or 1) + 1
        self._shapeCombo[shapeName] = count
        self._comboMultiplier = math.min(3.0, 1.0 + 0.15 * (count - 1)) -- +15% per repeat, max 3.0x
    else
        self._shapeCombo[shapeName] = 1
        self._comboMultiplier = 1.0
    end
    self._lastShapeName = shapeName

    -- Speed bonus for fast drawings (< 2s gives up to +25%)
    local speedBonusMult = 1.0
    if drawData.drawTime and drawData.drawTime > 0 then
        if drawData.drawTime <= 2.0 then
            speedBonusMult = 1.25
        elseif drawData.drawTime <= 3.0 then
            speedBonusMult = 1.15
        elseif drawData.drawTime <= 5.0 then
            speedBonusMult = 1.05
        end
    end
    local totalMult = self._comboMultiplier * speedBonusMult
    scoreResult.totalScore = math.floor(scoreResult.totalScore * totalMult)
    
    -- Update game state
    shapeChallenge.result = scoreResult
    shapeChallenge.completed = true
    shapeScore = shapeScore + scoreResult.totalScore
    -- Track accuracy/stars for UI
    self.shapeAccuracy = math.floor((matchResult.accuracy or 0) * 100)
    -- ENHANCED: Precise Star Rewards based on accuracy tiers
    if (currentShapeTemplate and currentShapeTemplate.name == targetShapeId) and (self.shapeAccuracy >= self:getRequiredAccuracyForLevel(level)) then
        local newStars = 0
        -- Star tiers: 80-89% = 1 star, 90-95% = 2 stars, 96%+ = 3 stars
        if self.shapeAccuracy >= 96 then
            newStars = 3
        elseif self.shapeAccuracy >= 90 then
            newStars = 2
        elseif self.shapeAccuracy >= self:getRequiredAccuracyForLevel(level) then
            newStars = 1
        end
        
        -- Only award stars if better than current
        local currentStars = ShapeFeedback:getStarCount() or 0
        if newStars > currentStars then
            ShapeFeedback:setStars(newStars)
            if ok_cfg and Config.debug and Config.debug.enabled then 
                print("NEW STAR RECORD! Earned", newStars, "stars with", self.shapeAccuracy, "% accuracy")
            end
        end
    end
    self.shapeStarsEarned = ShapeFeedback:getStarCount()
    self.shapeStarsTarget = 3
    if self.shapePanel then
        self.shapePanel:setProgress(self.shapeAccuracy, self.shapeStarsEarned, self.shapeStarsTarget)
        self.shapePanel:flashSuccess()
    end
    
    -- Update visual feedback system
    ShapeFeedback:setShapeCompleted(true, matchResult.accuracy)
    
    -- ENHANCED: Mark target shape area in green when successfully completed
    if (currentShapeTemplate and currentShapeTemplate.name == targetShapeId) and 
       (self.shapeAccuracy >= self:getRequiredAccuracyForLevel(level)) and
       Player and Player.trail and #Player.trail > 0 then
        -- Convert node trail to cell trail for green highlighting
        local cellTrail = {}
        for _, node in ipairs(Player.trail) do
            local cellI = math.min(node.i, Grid.width)
            local cellJ = math.min(node.j, Grid.height)
            table.insert(cellTrail, {i = cellI, j = cellJ})
        end
        Grid:markTargetShapeCompleted(cellTrail)
        if ok_cfg and Config.debug and Config.debug.enabled then print("Marked target shape area as GREEN!") end
        
        -- ENHANCED: Auto-advance to next level when target shape is completed successfully
        local claimedPercent = Grid:getClaimedPercent() * 100
        local requiredTerr = self:getRequiredTerritoryForLevel(level)
        if claimedPercent >= requiredTerr then
            -- Both territory and shape objectives met - advance immediately
            self._levelCompletionDelay = 2.0  -- Brief celebration delay
            if ok_cfg and Config.debug and Config.debug.enabled then print("LEVEL COMPLETE! Auto-advancing in 2 seconds...") end
        else
            if ok_cfg and Config.debug and Config.debug.enabled then 
                print("Target shape completed! Need", requiredTerr - claimedPercent, "% more territory to advance") 
            end
        end
    end
    
    if ok_cfg and Config.debug and Config.debug.enabled then
        print("Shape drawing completed!")
        print("Accuracy:", math.floor(matchResult.accuracy * 100) .. "%")
        print("Grade:", scoreResult.grade)
        print("Score:", scoreResult.totalScore)
    end
    if self._comboMultiplier and self._comboMultiplier > 1.0 then
    if ok_cfg and Config.debug and Config.debug.enabled then print(string.format("Combo x%.2f (streak %d)", self._comboMultiplier, self._shapeCombo[shapeName] or 1)) end
    end
    if drawData.drawTime then
    if ok_cfg and Config.debug and Config.debug.enabled then print(string.format("Time: %.2fs (speed mult x%.2f)", drawData.drawTime, speedBonusMult)) end
    end
    if ok_cfg and Config.debug and Config.debug.enabled then print("Stars earned:", ShapeFeedback:getStarCount()) end
    
    -- Visual/audio feedback
    self:showShapeResult(scoreResult)

    -- Auto-advance only when both goals satisfied
    local claimedPercent = Grid:getClaimedPercent() * 100
    local requiredTerr = self:getRequiredTerritoryForLevel(level)
    local requiredAcc = self:getRequiredAccuracyForLevel(level)
    local territoryComplete = claimedPercent >= requiredTerr
    local shapeOK = (self.shapeAccuracy or 0) >= requiredAcc and (currentShapeTemplate and currentShapeTemplate.name == targetShapeId)
    if territoryComplete and shapeOK then
        self:handleLevelComplete()
    end
end

function Game:showShapeResult(scoreResult)
    -- This will be called to show the shape result UI
    -- For now, just print the result
    local display = ShapeScore:getScoreDisplay(scoreResult)
    if ok_cfg and Config.debug and Config.debug.enabled then print("Shape Result:", display.title, "- Score:", scoreResult.totalScore) end
end

function Game:handlePlayerEnemyCollision()
    if ok_cfg and Config.debug and Config.debug.enabled then print("Player hit by enemy!") end
    
    if Player.isDrawing then
        -- Cancel current trail
        Player:cancelTrail(Grid)
    if ok_cfg and Config.debug and Config.debug.enabled then print("Trail cancelled due to enemy collision") end
    else
        -- Player is in safe zone, lose a life
        livesRemaining = livesRemaining - 1
    if ok_cfg and Config.debug and Config.debug.enabled then print("Life lost! Lives remaining:", livesRemaining) end
        
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
    if ok_cfg and Config.debug and Config.debug.enabled then print("Enemy hit player trail!") end
    Player:cancelTrail(Grid)
end

function Game:handleLevelComplete()
    gameWon = true
    score = score + 1000 + (level * 500)
    if ok_cfg and Config.debug and Config.debug.enabled then print("Level", level, "complete! Score:", score) end
    
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
    
    -- Reset shape feedback for new level
    ShapeFeedback:reset()
    ShapeFeedback:setStars(0)
    
    -- Load new shape template for this level
    self:loadLevelShape()
    -- Update HUD requirement for new level
    Grid:setRequiredClaimedPercent(self:getRequiredTerritoryForLevel(level) / 100)
    
    gameWon = false
    if ok_cfg and Config.debug and Config.debug.enabled then print("Advanced to level", level, "- New target:", targetPercentage .. "%") end
    _G.currentLevel = level
end

-- Load/refresh shape for the current level and update UI panel
function Game:loadLevelShape()
    currentShapeTemplate = ShapeTemplates:getShapeForLevel(level)
    if currentShapeTemplate then
    targetShapeId = currentShapeTemplate.name
        if self.shapePanel then
            self.shapePanel:setTemplate(currentShapeTemplate.name, currentShapeTemplate.points, currentShapeTemplate.requiredAccuracy or self:getRequiredAccuracyForLevel(level))
        end
    end
end

-- Difficulty scaling rules
function Game:getRequiredAccuracyForLevel(levelNumber)
    return math.min(95, 80 + (levelNumber - 1) * 2)
end

function Game:getRequiredTerritoryForLevel(levelNumber)
    -- Start at 75%, +2% per level, cap at 85%
    return math.min(85, 75 + (levelNumber - 1) * 2)
end

function Game:handleGameOver()
    gameOver = true
    if ok_cfg and Config.debug and Config.debug.enabled then print("Game Over! Final Score:", score) end
end

function Game:draw()
    -- Draw grid (includes territory and trails)
    Grid:draw()
    
    -- Draw shape template if shape challenge is active
    if self.shapeChallenge and self.shapeChallenge.active and currentShapeTemplate then
        self:drawShapeTemplateWithFeedback()
    end
    
    -- Draw player's drawing path (instance)
    if self.drawPath and self.drawPath.draw and self.debugDrawPath then self.drawPath:draw() end
    
    -- Draw enemies (boss is larger and purple)
    for _, enemy in ipairs(Enemies) do
        local x = Grid.offsetX + (enemy.i - 1) * Grid.cellSize + Grid.cellSize/2
        local y = Grid.offsetY + (enemy.j - 1) * Grid.cellSize + Grid.cellSize/2
        -- Telegraph: draw a faint line from previous to current position
        if enemy.prevI and enemy.prevJ and enemy.telegraphTimer then
            local px = Grid.offsetX + (enemy.prevI - 1) * Grid.cellSize + Grid.cellSize/2
            local py = Grid.offsetY + (enemy.prevJ - 1) * Grid.cellSize + Grid.cellSize/2
            local alpha = math.max(0, math.min(1, enemy.telegraphTimer / 0.15)) * 0.5
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.setLineWidth(2)
            love.graphics.line(px, py, x, y)
            love.graphics.setLineWidth(1)
        end
        if enemy.isBoss then
            love.graphics.setColor(0.7, 0.2, 1.0, 1)
            love.graphics.circle("fill", x, y, math.max(6, Grid.cellSize * 0.45))
        else
            love.graphics.setColor(0.9, 0.2, 0.2, 1) -- Red
            love.graphics.circle("fill", x, y, math.max(3, Grid.cellSize * 0.33))
        end
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
    
    -- Stats -> right-side panel only (no on-grid text)
    self:collectAndSendStats()
    -- Overlay HUD (warnings, ability bar, etc.)
    if IngameHUD and IngameHUD.draw then
        IngameHUD:draw(self, Player, Grid, self.powerups, nil)
    end
    
    -- Optionally draw any shape challenge overlays (kept minimal)
    -- Draw shape panel on the right
    if self.shapePanel then self.shapePanel:draw() end
    
    -- Draw game over/win screen
    if gameOver then
        self:drawGameOverScreen()
    elseif gameWon then
        self:drawLevelCompleteScreen()
    end

    -- Draw toast message last
    if toast.msg and toast.timer and toast.timer > 0 then
        local w, h = love.graphics.getDimensions()
        local padding = 8
        local text = toast.msg
        local prev = love.graphics.getFont()
        local font = love.graphics.newFont(14)
        love.graphics.setFont(font)
        local tw = font:getWidth(text)
        local th = font:getHeight()
        local bx = 10
        local by = h - th - 20
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle('fill', bx - padding, by - padding, tw + padding*2, th + padding*2, 6, 6)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(text, bx, by)
        if prev then love.graphics.setFont(prev) end
    end
end

-- Aggregate gameplay stats and push to the right-side panel
function Game:collectAndSendStats()
    if not self.shapePanel then return end
    local claimedPercent = math.floor((Grid:getClaimedPercent() or 0) * 100)
    local requiredTerr = self:getRequiredTerritoryForLevel(level)
    local requiredAcc = self:getRequiredAccuracyForLevel(level)
    local stats = {
        level = level,
        target = currentShapeTemplate and currentShapeTemplate.name or 'Triangle',
        requiredAcc = requiredAcc,
        claimed = claimedPercent,
        requiredClaimed = requiredTerr,
        shapeAcc = self.shapeAccuracy or 0,
        lives = livesRemaining,
        enemies = #Enemies,
        time = math.floor(gameTime),
        score = score,
        combo = self._comboMultiplier or 1.0
    }
    if self.shapePanel.setStats then
        self.shapePanel:setStats(stats)
    end
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

function Game:drawShapeTemplateWithFeedback()
    if not currentShapeTemplate then return end
    
    -- Position the template on the right side of the screen
    local screenWidth = love.graphics.getWidth()
    local templateX = screenWidth - 200
    local templateY = 20
    local scale = 1.0
    
    -- Draw stars above the template
    ShapeFeedback:drawStars(templateX, templateY, scale)
    
    -- Draw the template with current feedback state
    ShapeFeedback:drawShapeTemplate(currentShapeTemplate, templateX, templateY + 30, scale)
end

function Game:drawShapeTemplate()
    -- Legacy function - redirects to new feedback system
    self:drawShapeTemplateWithFeedback()
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
    
    -- Draw simple instruction at the bottom
    local instruction = "Draw the shape shown on the right!"
    if ShapeFeedback:isCompleted() then
        instruction = "Shape completed! " .. ShapeFeedback:getStarCount() .. " stars earned!"
        love.graphics.setColor(0.2, 1, 0.2, 1) -- Green for success
    end
    
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf(instruction, 0, love.graphics.getHeight() - 80, screenWidth, "center")
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
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
    elseif key == "f3" then
        -- Runtime debug toggle
        if ok_cfg and Config.debug then
            Config.debug.enabled = not Config.debug.enabled
            toast.msg = Config.debug.enabled and "Debug: ON" or "Debug: OFF"
            toast.timer = 1.5
        end
    elseif key == "r" and gameOver then
        level = 1
        score = 0
        self:initializeGame()
    end
end

function Game:resize(w, h)
    local rightPanePx = math.floor(math.max(260, math.min(380, 0.22 * w)))
    Grid:setSizeToWindow(w, h, 16, rightPanePx)
    if self.shapePanel then
        local panelW = 220
        local panelX = w - rightPanePx + 10
        self.shapePanel.x = panelX
        self.shapePanel.y = 16
        self.shapePanel.w = panelW
    end
    if self.drawPath then self.drawPath.grid = Grid end
end

return Game
