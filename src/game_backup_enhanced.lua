-- Voidline Game Module - Complete Enhanced Version
local Grid = require 'src.grid'
local Player = require 'src.player'
local ShapeTemplates = require 'src.systems.shape_templates'
local DrawPathSystem = require 'src.systems.draw_path_system'
local ShapeMatcher = require 'src.systems.shape_matcher'
local ShapeScore = require 'src.systems.shape_score'
local Timer = require 'hump.timer'

-- Load abilities
local PanicPulse = require 'src.abilities.panic_pulse'
local ZoneMirror = require 'src.abilities.zone_mirror'

-- Load achievements system
local Achievements = require 'src.ui.achievements'

-- Load tutorial system
local Tutorial = require 'src.ui.tutorial'

local Game = {}

-- Game state variables
local gameOver = false
local gameWon = false
local level = 1
local territoryScore = 0
local shapeScore = 0
local totalScore = 0
local livesRemaining = 3
local gameTime = 0
local targetPercentage = 75
local currentTerritoryPercentage = 0
local Enemies = {}
local enemySpawnTimer = 0
local enemySpawnDelay = 3.0

-- Shape feedback system
local shapeDrawingFeedback = {
    active = false,
    message = "",
    timer = 0,
    color = {1, 1, 1, 1},
    type = "none" -- "success", "failure", "drawing"
}

-- REVOLUTIONARY Multiple Shape Bonus System
local shapeChallenge = {
    active = true,
    currentTemplate = nil,
    targetShapeAccuracy = 80,
    currentAccuracy = 0,
    maxTimeForBonus = 45,
    timeElapsed = 0,
    -- NEW: Multiple shape completion tracking
    completedShapes = 0,        -- How many shapes completed this level
    perfectShapes = 0,          -- Shapes completed with 95%+ accuracy
    shapeMultiplier = 1.0,      -- Score multiplier for repeated shapes
    lastCompletionTime = 0,     -- Time of last shape completion
    fastCompletionBonus = 0,    -- Bonus for quick consecutive shapes
    shapeMasterBonus = false    -- Activated when completing 3+ shapes perfectly
}

function Game:load()
    print("Voidline Game loaded - Enhanced Complete Version")
end

function Game:init()
    print("Initializing Enhanced Voidline Game")
    _G.currentGame = self  -- Set global reference for player feedback
    self:initializeGame()
end

function Game:initializeGame()
    gameOver = false
    gameWon = false
    level = 1
    territoryScore = 0
    shapeScore = 0
    totalScore = 0
    livesRemaining = 3
    gameTime = 0
    targetPercentage = 75  -- Restore to 75% as requested
    currentTerritoryPercentage = 0
    Enemies = {}
    enemySpawnTimer = 0
    enemySpawnDelay = 3.0
    
    -- ✅ DOPAMINE FEEDBACK SYSTEM - Initialize streak tracking
    self.streakSystem = {
        territoryStreak = 0,        -- Consecutive territory captures
        shapeStreak = 0,           -- Consecutive successful shapes
        comboStreak = 0,           -- Both territory + shape in same level
        lastCelebrationTime = 0,
        particles = {},            -- Celebration particles
        maxParticles = 50
    }
    
    -- Reset notification flags
    self._territoryCompleteNotified = false
    self._shapeCompleteNotified = false
    self._hasCompletedShapeThisLevel = false  -- Track first-time vs repeat success
    
    -- Reset success feedback state
    self._successTriggered = false
    self._successFlashTimer = 0
    self._successMessageTimer = 0
    
    -- Initialize core systems
    Grid:load()
    Player:load(Grid)
    DrawPathSystem:init()
    ShapeMatcher:init()
    ShapeScore:init()
    
    -- ✅ MAKE DRAWPATHSYSTEM GLOBALLY ACCESSIBLE
    _G.DrawPathSystem = DrawPathSystem
    
    -- Initialize abilities
    PanicPulse:load()
    ZoneMirror:load()
    
    -- Initialize achievements
    Achievements:load()
    
    -- Start tutorial for new players (level 1 only)
    if level == 1 then
        Tutorial:start()
    end
    
    -- Initialize shape challenge with 50-level progression system
    shapeChallenge.active = true
    shapeChallenge.currentTemplate = ShapeTemplates:getShapeForLevel(level)
    
    -- Get level-specific shape requirements
    local shapeInfo = shapeChallenge.currentTemplate
    if shapeInfo then
        shapeChallenge.targetShapeAccuracy = shapeInfo.requiredAccuracy or 80
        print("🎯 LEVEL " .. level .. " - Target: " .. (shapeInfo.name or "Unknown"))
        print("   Required Accuracy: " .. shapeChallenge.targetShapeAccuracy .. "%")
        print("   Difficulty: " .. (shapeInfo.difficulty or 1) .. "/9")
        print("   Shape " .. level .. " of 50")
    else
        shapeChallenge.targetShapeAccuracy = 80  -- Fallback
    end
    
    shapeChallenge.currentAccuracy = 0
    shapeChallenge.timeElapsed = 0
    shapeChallenge.completedShapes = 0
    shapeChallenge.perfectShapes = 0
    shapeChallenge.shapeMultiplier = 1.0
    shapeChallenge.lastCompletionTime = 0
    shapeChallenge.fastCompletionBonus = 0
    shapeChallenge.shapeMasterBonus = false
    
    -- Initialize completion tracking
    self._lastShapeComplete = false
    
    -- Spawn enemies
    self:spawnEnemiesForLevel()
    
    print("Game initialized for level", level)
end

function Game:spawnEnemiesForLevel()
    local EnemyTypes = require 'src.enemy.init'
    Enemies = {} -- Clear existing enemies
    
    -- ENHANCED PROGRESSIVE DIFFICULTY SYSTEM
    local baseEnemyCount = 2 + math.floor(level / 2) -- Base: 2-3 enemies early, scaling up
    local maxEnemies = math.min(8, baseEnemyCount) -- Cap at 8 enemies
    
    -- Dynamic enemy type selection based on level
    local availableEnemyTypes = {}
    
    -- Level 1-3: Basic enemies only
    if level <= 3 then
        availableEnemyTypes = {'Chaser', 'Reclaimer'}
    -- Level 4-7: Add intermediate enemies
    elseif level <= 7 then
        availableEnemyTypes = {'Chaser', 'Reclaimer', 'Jammer', 'GuardianBreaker'}
    -- Level 8-12: Add advanced enemies
    elseif level <= 12 then
        availableEnemyTypes = {'Chaser', 'Reclaimer', 'Jammer', 'GuardianBreaker', 'Phaser', 'Infester'}
    -- Level 13+: All enemy types including boss-level
    else
        availableEnemyTypes = {'Chaser', 'Reclaimer', 'Jammer', 'GuardianBreaker', 'Phaser', 'Infester', 'Splitter', 'Teleporter'}
        -- 15% chance of boss enemy in late levels
        if math.random() < 0.15 then
            table.insert(availableEnemyTypes, 'ReclaimerBoss')
        end
    end
    
    for i = 1, maxEnemies do
        local enemyType = availableEnemyTypes[math.random(1, #availableEnemyTypes)]
        local enemy = nil
        
        -- Find valid spawn position (not in claimed territory)
        local spawnI, spawnJ
        local attempts = 0
        repeat
            spawnI = math.random(2, Grid.width - 1)
            spawnJ = math.random(2, Grid.height - 1)
            attempts = attempts + 1
        until (not Grid:isClaimed(spawnI, spawnJ)) or attempts > 50 -- Safety limit
        
        -- Create enemy with level-based scaling
        if enemyType == 'Chaser' and EnemyTypes.Chaser then
            enemy = EnemyTypes.Chaser:new(spawnI, spawnJ, level)
        elseif enemyType == 'Reclaimer' and EnemyTypes.Reclaimer then
            enemy = EnemyTypes.Reclaimer:new(spawnI, spawnJ, level)
        elseif enemyType == 'Jammer' and EnemyTypes.Jammer then
            enemy = EnemyTypes.Jammer:new(spawnI, spawnJ, level)
        elseif enemyType == 'GuardianBreaker' and EnemyTypes.GuardianBreaker then
            enemy = EnemyTypes.GuardianBreaker:new(spawnI, spawnJ)
            enemy.level = level  -- Set level manually after creation
        elseif enemyType == 'Phaser' and EnemyTypes.Phaser then
            enemy = EnemyTypes.Phaser:new(spawnI, spawnJ)
            enemy.level = level
        elseif enemyType == 'Infester' and EnemyTypes.Infester then
            enemy = EnemyTypes.Infester:new(spawnI, spawnJ)
            enemy.level = level
        elseif enemyType == 'Splitter' and EnemyTypes.Splitter then
            enemy = EnemyTypes.Splitter:new(spawnI, spawnJ)
            enemy.level = level
        elseif enemyType == 'Teleporter' and EnemyTypes.Teleporter then
            enemy = EnemyTypes.Teleporter:new(spawnI, spawnJ)
            enemy.level = level
        elseif enemyType == 'ReclaimerBoss' and EnemyTypes.ReclaimerBoss then
            enemy = EnemyTypes.ReclaimerBoss:new(spawnI, spawnJ)
            enemy.level = level
        else
            -- Fallback to basic chaser
            enemy = EnemyTypes.Chaser:new(spawnI, spawnJ, level)
        end
        
        if enemy then
            -- PROGRESSIVE DIFFICULTY SCALING: Enhance enemy stats based on level
            enemy.level = level
            enemy.baseSpeed = enemy.moveDelay or 0.5
            
            -- Speed scaling: enemies get faster but never unfairly fast
            local speedMultiplier = 1.0 - (level * 0.03) -- 3% faster per level
            speedMultiplier = math.max(0.6, speedMultiplier) -- Never faster than 40% speed increase
            enemy.moveDelay = enemy.baseSpeed * speedMultiplier
            
            -- Aggression scaling: enemies become more aggressive when player draws
            enemy.aggressionLevel = math.min(2.0, 1.0 + (level * 0.08)) -- Up to 2x aggression
            
            -- Special abilities unlock at higher levels
            if level >= 5 then
                enemy.canPredictMovement = true
            end
            if level >= 8 then
                enemy.reactsToDrawing = true
            end
            if level >= 12 then
                enemy.coordinatesWithOthers = true
            end
            
            table.insert(Enemies, enemy)
        end
    end
    
    print("🚀 DIFFICULTY SYSTEM: Spawned", #Enemies, "enemies for level", level)
    print("   Enemy types:", table.concat(availableEnemyTypes, ", "))
    if #Enemies > 0 and Enemies[1].moveDelay and Enemies[1].baseSpeed then
        print("   Speed boost:", math.floor((1.0 - (Enemies[1].moveDelay/Enemies[1].baseSpeed)) * 100), "%")
    end
end

function Game:update(dt)
    if gameOver or gameWon then return end
    
    gameTime = gameTime + dt
    Timer.update(dt)
    
    -- Update abilities
    PanicPulse:update(dt)
    ZoneMirror:update(dt)
    
    -- Update achievements notifications
    Achievements:updateNotifications(dt)
    
    -- Update tutorial
    local tutorialData = {
        territoryPercent = currentTerritoryPercentage,
        shapeAccuracy = shapeChallenge.currentAccuracy,
        level = level
    }
    Tutorial:update(dt, Player, Enemies, tutorialData)
    
    -- Update player immunity from abilities
    if Player.panicPulseImmunity and Player.panicPulseImmunity > 0 then
        Player.panicPulseImmunity = Player.panicPulseImmunity - dt
    end
    
    -- Update systems
    Grid:update(dt)
    Player:update(dt, Grid)
    
    -- ✅ UPDATE DRAWING SYSTEM BASED ON PLAYER MOVEMENT
    if DrawPathSystem and DrawPathSystem.isDrawing then
        local playerX, playerY = Grid:getNodePixelPosition(Player.i, Player.j)
        DrawPathSystem:addPoint(playerX, playerY)
    end
    
    -- Update enemies
    self:updateEnemies(dt)
    
    -- Check collisions (with ability immunity)
    if not PanicPulse:isPlayerImmune(Player) then
        self:checkCollisions()
    end
    
    -- Update territory percentage
    currentTerritoryPercentage = self:calculateTerritoryPercentage()
    
    -- ✅ UPDATE AUTO-PROGRESSION TIMER
    if self._autoProgressTimer and self._autoProgressTimer > 0 then
        self._autoProgressTimer = self._autoProgressTimer - dt
        if self._autoProgressTimer <= 0 then
            -- Auto-advance to next level
            if level >= 50 then
                -- Return to main menu after completing all levels
                print("ADVANCE: from=" .. level .. " to=COMPLETE")
                local Gamestate = require 'hump.gamestate'
                local Menu = require 'src.ui.menu'
                Gamestate.switch(Menu)
            else
                -- Advance to next level
                print("ADVANCE: from=" .. level .. " to=" .. (level + 1))
                level = level + 1
                print("LOADED LEVEL: " .. level)
                
                -- Reset all game state for new level
                self:initializeGame()
                gameWon = false
                gameOver = false
                
                -- Clear any lingering feedback
                shapeDrawingFeedback.active = false
                self._successTriggered = false
            end
        end
    end

    -- Update shape challenge with VISUAL FEEDBACK
    if shapeChallenge.active then
        shapeChallenge.timeElapsed = shapeChallenge.timeElapsed + dt
        
        -- Show "Drawing shape..." when player is actively drawing
        if DrawPathSystem.isDrawing and #DrawPathSystem.currentPath > 2 then
            shapeDrawingFeedback.active = true
            shapeDrawingFeedback.message = "Drawing " .. (shapeChallenge.currentTemplate and shapeChallenge.currentTemplate.name or "Shape") .. "..."
            shapeDrawingFeedback.timer = 0.1
            shapeDrawingFeedback.color = {0.8, 0.8, 1, 1}
            shapeDrawingFeedback.type = "drawing"
        end
        
        -- ✅ ENHANCED WORKING SHAPE MATCHING SYSTEM WITH PROPER VALIDATION
        if DrawPathSystem.currentPath and #DrawPathSystem.currentPath >= 4 and shapeChallenge.active then
            print("🔍 SHAPE DEBUG: Shape matching triggered! Path points:", #DrawPathSystem.currentPath)
            local currentTemplate = shapeChallenge.currentTemplate
            if currentTemplate then
                print("🔍 SHAPE DEBUG: Current template:", currentTemplate.name)
                local path = DrawPathSystem.currentPath
                local pathLength = #path
                
                -- Create player path for shape matching
                local playerPath = {
                    points = {}
                }
                
                -- Convert pixel coordinates to normalized coordinates for matching
                local screenWidth = love.graphics.getWidth()
                local screenHeight = love.graphics.getHeight()
                for _, point in ipairs(path) do
                    local x = point.x / screenWidth
                    local y = point.y / screenHeight
                    table.insert(playerPath.points, {x = x, y = y})
                end
                
                -- Use the proper shape matcher for accurate validation
                local matchResult = ShapeMatcher:matchShape(playerPath, currentTemplate)
                local calculatedAccuracy = (matchResult.accuracy or 0) * 100
                
                print("🔍 SHAPE DEBUG: Raw match result:", matchResult.accuracy, "->", calculatedAccuracy, "%")
                print("🔍 SHAPE DEBUG: Match details:", matchResult.details or "none")
                
                -- Enhanced shape-specific validation with drawn path
                local shapeType = currentTemplate.type or "triangle"
                local baseAccuracy = calculatedAccuracy
                
                -- Apply shape-specific bonuses and penalties using path points
                if shapeType == "triangle" then
                    -- Triangle: Check for 3-sided polygon characteristics
                    local corners = self:detectCornersFromPath(path)
                    if #corners >= 2 and #corners <= 4 then  -- Allow some tolerance
                        baseAccuracy = baseAccuracy + 15
                    end
                    
                    -- Check for closure (start and end points close)
                    if self:isPathClosedFromPoints(path) then
                        baseAccuracy = baseAccuracy + 15
                    else
                        baseAccuracy = baseAccuracy - 10
                    end
                    
                elseif shapeType == "square" then
                    -- Square: Check for 4-sided polygon with right angles
                    local corners = self:detectCornersFromPath(path)
                    if #corners >= 3 and #corners <= 5 then  -- Allow some tolerance
                        baseAccuracy = baseAccuracy + 15
                    end
                    
                    -- Check aspect ratio for square-ness
                    local bounds = self:getBoundsFromPath(path)
                    local aspectRatio = math.min(bounds.width, bounds.height) / math.max(bounds.width, bounds.height)
                    if aspectRatio >= 0.7 then
                        baseAccuracy = baseAccuracy + 15
                    else
                        baseAccuracy = baseAccuracy - 10
                    end
                    
                    if self:isPathClosedFromPoints(path) then
                        baseAccuracy = baseAccuracy + 15
                    else
                        baseAccuracy = baseAccuracy - 10
                    end
                    
                elseif shapeType == "circle" then
                    -- Circle: Check for smoothness and roundness
                    local smoothness = self:calculateSmoothnessFromPath(path)
                    baseAccuracy = baseAccuracy + (smoothness * 25)  -- Up to 25 bonus for smooth curves
                    
                    -- Check for circular proportions
                    local bounds = self:getBoundsFromPath(path)
                    local aspectRatio = math.min(bounds.width, bounds.height) / math.max(bounds.width, bounds.height)
                    if aspectRatio >= 0.8 then
                        baseAccuracy = baseAccuracy + 20  -- Round proportions
                    else
                        baseAccuracy = baseAccuracy - 15
                    end
                    
                    -- Circles should be approximately closed
                    if self:isPathClosedFromPoints(path, 30) then  -- Allow pixel tolerance for circles
                        baseAccuracy = baseAccuracy + 15
                    else
                        baseAccuracy = baseAccuracy - 10
                    end
                    
                else
                    -- Default: basic validation for other shapes
                    if self:isPathClosedFromPoints(path) then
                        baseAccuracy = baseAccuracy + 10
                    end
                    
                    -- Size bonus for substantial drawings
                    local bounds = self:getBoundsFromPath(path)
                    local minSize = math.min(bounds.width, bounds.height)
                    if minSize >= 100 then  -- At least 100 pixels
                        baseAccuracy = baseAccuracy + 10
                    end
                end
                
                -- Size validation (too small shapes are penalized)
                local bounds = self:getBoundsFromPath(path)
                local minSize = math.min(bounds.width, bounds.height)
                if minSize < 50 then  -- Less than 50 pixels
                    baseAccuracy = baseAccuracy - 25
                elseif minSize >= 150 then  -- 150+ pixels is good
                    baseAccuracy = baseAccuracy + 15
                end
                
                -- Set accuracy with proper bounds
                shapeChallenge.currentAccuracy = math.max(0, math.min(100, baseAccuracy))
                
                -- ENHANCED VISUAL FEEDBACK: Show accurate feedback when shape is complete
                if not DrawPathSystem.isDrawing and #path > 3 then
                    local accuracy = shapeChallenge.currentAccuracy
                    
                    if accuracy >= shapeChallenge.targetShapeAccuracy then
                        -- ✅ SUCCESS WITH ENHANCED DOPAMINE FEEDBACK!
                        shapeDrawingFeedback.active = true
                        
                        -- Check if this is first-time success or repeat success
                        local isFirstTime = not self._hasCompletedShapeThisLevel
                        self._hasCompletedShapeThisLevel = true
                        
                        if isFirstTime then
                            -- FIRST-TIME SUCCESS - MAXIMUM EXCITEMENT!
                            shapeDrawingFeedback.message = "🌟 PERFECT MATCH! AMAZING! 🌟 " .. math.floor(accuracy) .. "%"
                            shapeDrawingFeedback.timer = 4.0  -- Longer celebration
                            shapeDrawingFeedback.color = {1.0, 1.0, 0.2, 1}  -- Bright gold
                            shapeDrawingFeedback.type = "first_success"
                            
                            -- Trigger celebration effects
                            self._celebrationTimer = 3.0
                            self._sparkleEffect = true
                            self._screenFlashTimer = 0.5
                            
                            print("🎉🎉🎉 FIRST-TIME PERFECT MATCH! 🎉🎉🎉")
                            print("🌟 INCREDIBLE! " .. math.floor(accuracy) .. "% " .. shapeType .. " accuracy!")
                        else
                            -- REPEAT SUCCESS - ENCOURAGING FEEDBACK
                            local encouragingMessages = {
                                "✨ EXCELLENT RECOVERY! ✨",
                                "💪 GREAT IMPROVEMENT! 💪",
                                "🎯 NICE CONSISTENCY! 🎯",
                                "⭐ WELL DONE AGAIN! ⭐",
                                "🔥 ON FIRE! 🔥"
                            }
                            local randomMessage = encouragingMessages[math.random(1, #encouragingMessages)]
                            
                            shapeDrawingFeedback.message = randomMessage .. " " .. math.floor(accuracy) .. "%"
                            shapeDrawingFeedback.timer = 3.0
                            shapeDrawingFeedback.color = {0.2, 1.0, 0.8, 1}  -- Bright cyan
                            shapeDrawingFeedback.type = "repeat_success"
                            
                            -- Medium celebration
                            self._celebrationTimer = 1.5
                            self._pulseEffect = true
                            
                            print("✨ REPEAT SUCCESS: " .. randomMessage)
                        end
                        
                        -- Common success effects
                        print("✅ SHAPE SUCCESS: " .. math.floor(accuracy) .. "% " .. shapeType .. " (Required: " .. shapeChallenge.targetShapeAccuracy .. "%)")
                        
                        -- Mark shape as completed
                        if not self._shapeJustCompleted then
                            self._shapeJustCompleted = true
                            print("🎯 SHAPE COMPLETED: " .. shapeType .. " with " .. math.floor(accuracy) .. "% accuracy!")
                        end
                        
                    elseif accuracy >= shapeChallenge.targetShapeAccuracy * 0.8 then
                        -- CLOSE BUT NOT ENOUGH
                        shapeDrawingFeedback.active = true
                        shapeDrawingFeedback.message = "⚠️ Close! " .. math.floor(accuracy) .. "% (Need " .. shapeChallenge.targetShapeAccuracy .. "%)"
                        shapeDrawingFeedback.timer = 2.5
                        shapeDrawingFeedback.color = {1.0, 0.8, 0.2, 1}
                        shapeDrawingFeedback.type = "close"
                        print("⚠️ SHAPE CLOSE: " .. math.floor(accuracy) .. "% " .. shapeType .. " (Required: " .. shapeChallenge.targetShapeAccuracy .. "%)")
                        
                    else
                        -- FAILED ATTEMPT - show specific feedback
                        shapeDrawingFeedback.active = true
                        shapeDrawingFeedback.message = "❌ Try Again! " .. math.floor(accuracy) .. "% - Practice the " .. shapeType .. " shape"
                        shapeDrawingFeedback.timer = 2.5
                        shapeDrawingFeedback.color = {1.0, 0.3, 0.3, 1}
                        shapeDrawingFeedback.type = "failure"
                        print("❌ SHAPE FAILED: " .. math.floor(accuracy) .. "% " .. shapeType .. " (Required: " .. shapeChallenge.targetShapeAccuracy .. "%)")
                    end
                    
                    self._shapeJustCompleted = false  -- Reset for next attempt
                end
            end
        elseif not DrawPathSystem.isDrawing and shapeChallenge.currentAccuracy > 0 then
            -- Slow accuracy decay when not drawing to allow multiple attempts
            shapeChallenge.currentAccuracy = math.max(0, shapeChallenge.currentAccuracy - dt * 5)
        end
    end
end
        
-- ✅ ENHANCED SHAPE ANALYSIS HELPER FUNCTIONS FOR PIXEL COORDINATES
function Game:detectCornersFromPath(path)
    if not path or #path < 3 then return {} end
    
    local corners = {}
    local angleThreshold = math.pi / 3  -- 60 degrees minimum for corner detection
    
    for i = 2, #path - 1 do
        local p1 = path[i - 1]
        local p2 = path[i]
        local p3 = path[i + 1]
        
        -- Calculate vectors
        local v1 = {x = p2.x - p1.x, y = p2.y - p1.y}
        local v2 = {x = p3.x - p2.x, y = p3.y - p2.y}
        
        -- Calculate angle between vectors
        local dot = v1.x * v2.x + v1.y * v2.y
        local mag1 = math.sqrt(v1.x^2 + v1.y^2)
        local mag2 = math.sqrt(v2.x^2 + v2.y^2)
        
        if mag1 > 0 and mag2 > 0 then
            local angle = math.acos(math.max(-1, math.min(1, dot / (mag1 * mag2))))
            if angle >= angleThreshold then
                table.insert(corners, {i = i, angle = angle, point = p2})
            end
        end
    end
    
    return corners
end

function Game:getBoundsFromPath(path)
    if not path or #path == 0 then
        return {width = 0, height = 0, minX = 0, maxX = 0, minY = 0, maxY = 0}
    end
    
    local minX, maxX = path[1].x, path[1].x
    local minY, maxY = path[1].y, path[1].y
    
    for _, point in ipairs(path) do
        minX = math.min(minX, point.x)
        maxX = math.max(maxX, point.x)
        minY = math.min(minY, point.y)
        maxY = math.max(maxY, point.y)
    end
    
    return {
        width = maxX - minX,
        height = maxY - minY,
        minX = minX,
        maxX = maxX,
        minY = minY,
        maxY = maxY
    }
end

function Game:isPathClosedFromPoints(path, tolerance)
    if not path or #path < 3 then return false end
    
    tolerance = tolerance or 20  -- Default 20-pixel tolerance
    local first = path[1]
    local last = path[#path]
    
    local distance = math.sqrt((first.x - last.x)^2 + (first.y - last.y)^2)
    return distance <= tolerance
end

function Game:calculateSmoothnessFromPath(path)
    if not path or #path < 3 then return 0 end
    
    local totalCurvature = 0
    local validPoints = 0
    
    for i = 2, #path - 1 do
        local p1 = path[i - 1]
        local p2 = path[i]
        local p3 = path[i + 1]
        
        -- Calculate direction change
        local v1 = {x = p2.x - p1.x, y = p2.y - p1.y}
        local v2 = {x = p3.x - p2.x, y = p3.y - p2.y}
        
        local mag1 = math.sqrt(v1.x^2 + v1.y^2)
        local mag2 = math.sqrt(v2.x^2 + v2.y^2)
        
        if mag1 > 0 and mag2 > 0 then
            local dot = v1.x * v2.x + v1.y * v2.y
            local angle = math.acos(math.max(-1, math.min(1, dot / (mag1 * mag2))))
            totalCurvature = totalCurvature + (math.pi - angle)  -- Invert so smooth = high score
            validPoints = validPoints + 1
        end
    end
    
    if validPoints == 0 then return 0 end
    return totalCurvature / (validPoints * math.pi)  -- Normalize to 0-1
end

-- Original helper functions for compatibility
function Game:detectCorners(trail)
    if not trail or #trail < 3 then return {} end
    
    local corners = {}
    local angleThreshold = math.pi / 3  -- 60 degrees minimum for corner detection
    
    for i = 2, #trail - 1 do
        local p1 = trail[i - 1]
        local p2 = trail[i]
        local p3 = trail[i + 1]
        
        -- Calculate vectors
        local v1 = {x = p2.i - p1.i, y = p2.j - p1.j}
        local v2 = {x = p3.i - p2.i, y = p3.j - p2.j}
        
        -- Calculate angle between vectors
        local dot = v1.x * v2.x + v1.y * v2.y
        local mag1 = math.sqrt(v1.x^2 + v1.y^2)
        local mag2 = math.sqrt(v2.x^2 + v2.y^2)
        
        if mag1 > 0 and mag2 > 0 then
            local angle = math.acos(math.max(-1, math.min(1, dot / (mag1 * mag2))))
            if angle >= angleThreshold then
                table.insert(corners, {i = i, angle = angle, point = p2})
            end
        end
    end
    
    return corners
end

function Game:countRightAngles(trail)
    local corners = self:detectCorners(trail)
    local rightAngleCount = 0
    local rightAngleThreshold = math.pi / 12  -- 15 degrees tolerance
    
    for _, corner in ipairs(corners) do
        local deviation = math.abs(corner.angle - math.pi / 2)  -- 90 degrees
        if deviation <= rightAngleThreshold then
            rightAngleCount = rightAngleCount + 1
        end
    end
    
    return rightAngleCount
end

function Game:getBounds(trail)
    if not trail or #trail == 0 then
        return {width = 0, height = 0, minI = 0, maxI = 0, minJ = 0, maxJ = 0}
    end
    
    local minI, maxI = trail[1].i, trail[1].i
    local minJ, maxJ = trail[1].j, trail[1].j
    
    for _, point in ipairs(trail) do
        minI = math.min(minI, point.i)
        maxI = math.max(maxI, point.i)
        minJ = math.min(minJ, point.j)
        maxJ = math.max(maxJ, point.j)
    end
    
    return {
        width = maxI - minI + 1,
        height = maxJ - minJ + 1,
        minI = minI,
        maxI = maxI,
        minJ = minJ,
        maxJ = maxJ
    }
end

function Game:isPathClosed(trail, tolerance)
    if not trail or #trail < 3 then return false end
    
    tolerance = tolerance or 2  -- Default 2-cell tolerance
    local first = trail[1]
    local last = trail[#trail]
    
    local distance = math.sqrt((first.i - last.i)^2 + (first.j - last.j)^2)
    return distance <= tolerance
end

function Game:calculateSmoothness(trail)
    if not trail or #trail < 3 then return 0 end
    
    local totalCurvature = 0
    local validPoints = 0
    
    for i = 2, #trail - 1 do
        local p1 = trail[i - 1]
        local p2 = trail[i]
        local p3 = trail[i + 1]
        
        -- Calculate direction change
        local v1 = {x = p2.i - p1.i, y = p2.j - p1.j}
        local v2 = {x = p3.i - p2.i, y = p3.j - p2.j}
        
        local mag1 = math.sqrt(v1.x^2 + v1.y^2)
        local mag2 = math.sqrt(v2.x^2 + v2.y^2)
        
        if mag1 > 0 and mag2 > 0 then
            local dot = v1.x * v2.x + v1.y * v2.y
            local angle = math.acos(math.max(-1, math.min(1, dot / (mag1 * mag2))))
            totalCurvature = totalCurvature + (math.pi - angle)  -- Invert so smooth = high score
            validPoints = validPoints + 1
        end
    end
    
    if validPoints == 0 then return 0 end
    return totalCurvature / (validPoints * math.pi)  -- Normalize to 0-1
end

function Game:calculateStraightness(trail, lineType)
    if not trail or #trail < 2 then return 0 end
    
    local first = trail[1]
    local last = trail[#trail]
    
    -- Calculate ideal line direction
    local idealDirection
    if lineType == "horizontal_line" then
        idealDirection = {x = 1, y = 0}
    elseif lineType == "vertical_line" then
        idealDirection = {x = 0, y = 1}
    else
        -- General line - use actual start/end direction
        local dx = last.i - first.i
        local dy = last.j - first.j
        local mag = math.sqrt(dx^2 + dy^2)
        if mag == 0 then return 0 end
        idealDirection = {x = dx / mag, y = dy / mag}
    end
    
    -- Check how well the trail follows this direction
    local totalDeviation = 0
    local segments = 0
    
    for i = 1, #trail - 1 do
        local p1 = trail[i]
        local p2 = trail[i + 1]
        
        local dx = p2.i - p1.i
        local dy = p2.j - p1.j
        local mag = math.sqrt(dx^2 + dy^2)
        
        if mag > 0 then
            local segmentDir = {x = dx / mag, y = dy / mag}
            -- Calculate angle deviation from ideal direction
            local dot = segmentDir.x * idealDirection.x + segmentDir.y * idealDirection.y
            local angle = math.acos(math.max(-1, math.min(1, dot)))
            totalDeviation = totalDeviation + angle
            segments = segments + 1
        end
    end
    
    if segments == 0 then return 0 end
    local avgDeviation = totalDeviation / segments
    return math.max(0, 1 - (avgDeviation / (math.pi / 4)))  -- Normalize, 45° = 0 score
end

-- ✅ ENHANCED Shape feedback system
        local currentTemplate = shapeChallenge.currentTemplate
        if currentTemplate and Player.isDrawing and #Player.trail >= 3 then
            local feedback = ShapeTemplates:getShapeFeedback(
                currentTemplate.type, 
                shapeChallenge.currentAccuracy
            )
            
            -- Store feedback for UI display
            shapeChallenge.currentFeedback = feedback
            shapeChallenge.feedbackTimer = 2.0  -- Show for 2 seconds
        elseif shapeChallenge.feedbackTimer then
            shapeChallenge.feedbackTimer = shapeChallenge.feedbackTimer - dt
            if shapeChallenge.feedbackTimer <= 0 then
                shapeChallenge.currentFeedback = nil
            end
        end
        
        -- Calculate ENHANCED shape score with multiple bonuses
        local timeBonus = math.max(0, (shapeChallenge.maxTimeForBonus - shapeChallenge.timeElapsed) / shapeChallenge.maxTimeForBonus)
        local baseShapeScore = math.floor(shapeChallenge.currentAccuracy * 10 + timeBonus * 500)
        
        -- Apply multipliers and bonuses
        local multipliedScore = baseShapeScore * shapeChallenge.shapeMultiplier
        local totalShapeScore = multipliedScore + shapeChallenge.fastCompletionBonus
        
        shapeScore = math.floor(totalShapeScore)
    end
    
    -- Update total score with shape master bonus
    territoryScore = math.floor(currentTerritoryPercentage * 100)
    totalScore = territoryScore + shapeScore
    if shapeChallenge.shapeMasterBonus then
        totalScore = totalScore + 1000  -- Add shape master bonus to display
    end
    
    -- Update success feedback timers
    if self._successFlashTimer and self._successFlashTimer > 0 then
        self._successFlashTimer = self._successFlashTimer - dt
    end
    if self._successMessageTimer and self._successMessageTimer > 0 then
        self._successMessageTimer = self._successMessageTimer - dt
    end
    
    -- Update shape completion feedback
    if self._shapeCompletionTimer and self._shapeCompletionTimer > 0 then
        self._shapeCompletionTimer = self._shapeCompletionTimer - dt
    end
    
    -- Update shape drawing feedback timer (NEW)
    if shapeDrawingFeedback.active and shapeDrawingFeedback.timer > 0 then
        shapeDrawingFeedback.timer = shapeDrawingFeedback.timer - dt
        if shapeDrawingFeedback.timer <= 0 then
            shapeDrawingFeedback.active = false
        end
    end
    
    -- Update level complete delay timer
    if self._levelCompleteDelay and self._levelCompleteDelay > 0 then
        self._levelCompleteDelay = self._levelCompleteDelay - dt
    end
    
    -- Update drawing blocked flash effect
    if self._drawingBlockedFlash and self._drawingBlockedFlash > 0 then
        self._drawingBlockedFlash = self._drawingBlockedFlash - dt
    end
    
    -- ✅ UPDATE CELEBRATION EFFECTS
    if self._celebrationTimer and self._celebrationTimer > 0 then
        self._celebrationTimer = self._celebrationTimer - dt
    end
    
    if self._screenFlashTimer and self._screenFlashTimer > 0 then
        self._screenFlashTimer = self._screenFlashTimer - dt
    end
    
    if self._sparkleEffect then
        -- Create sparkle particles (visual only, no actual particle system needed)
        self._sparkleTime = (self._sparkleTime or 0) + dt
        if self._sparkleTime > 3.0 then
            self._sparkleEffect = false
            self._sparkleTime = 0
        end
    end
    
    if self._pulseEffect then
        self._pulseTime = (self._pulseTime or 0) + dt
        if self._pulseTime > 1.5 then
            self._pulseEffect = false
            self._pulseTime = 0
        end
    end
    
    -- ✅ DOPAMINE FEEDBACK - Update celebration particles
    self:updateCelebrationParticles(dt)
    
    -- Check win/lose conditions
    self:checkGameConditions()
end

-- ✅ DOPAMINE FEEDBACK SYSTEM - Particle system for celebrations
function Game:updateCelebrationParticles(dt)
    for i = #self.streakSystem.particles, 1, -1 do
        local particle = self.streakSystem.particles[i]
        particle.life = particle.life - dt
        
        if particle.life <= 0 then
            table.remove(self.streakSystem.particles, i)
        else
            -- Update particle position
            particle.x = particle.x + particle.vx * dt
            particle.y = particle.y + particle.vy * dt
            particle.vy = particle.vy + 200 * dt  -- Gravity
            
            -- Update alpha based on life
            particle.alpha = particle.life / particle.maxLife
        end
    end
end

function Game:addCelebrationParticles(x, y, count, color)
    count = count or 10
    color = color or {1, 1, 0}  -- Default yellow
    
    for i = 1, count do
        if #self.streakSystem.particles < self.streakSystem.maxParticles then
            local angle = love.math.random() * math.pi * 2
            local speed = love.math.random(50, 150)
            
            table.insert(self.streakSystem.particles, {
                x = x,
                y = y,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed - 100,  -- Initial upward velocity
                life = love.math.random(1, 2),
                maxLife = 2,
                alpha = 1,
                color = {color[1], color[2], color[3]}
            })
        end
    end
end

function Game:drawCelebrationParticles()
    for _, particle in ipairs(self.streakSystem.particles) do
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], particle.alpha)
        love.graphics.circle('fill', particle.x, particle.y, 3)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Game:triggerDopamineFeedback(type, position)
    -- ✅ DOPAMINE FEEDBACK - Streak tracking and celebrations
    local currentTime = love.timer.getTime()
    
    if type == "territory" then
        self.streakSystem.territoryStreak = self.streakSystem.territoryStreak + 1
        self:addCelebrationParticles(position.x, position.y, 15, {0, 1, 0})  -- Green particles
        print("🎉 DOPAMINE-TERRITORY: Streak " .. self.streakSystem.territoryStreak .. " - Territory captured!")
        
    elseif type == "shape" then
        self.streakSystem.shapeStreak = self.streakSystem.shapeStreak + 1
        self:addCelebrationParticles(position.x, position.y, 20, {1, 1, 0})  -- Yellow particles
        print("⭐ DOPAMINE-SHAPE: Streak " .. self.streakSystem.shapeStreak .. " - Shape completed!")
        
        -- Add star animation
        if shapeChallenge then
            shapeChallenge._lastStarTime = currentTime
        end
        
    elseif type == "combo" then
        self.streakSystem.comboStreak = self.streakSystem.comboStreak + 1
        self:addCelebrationParticles(position.x, position.y, 30, {1, 0, 1})  -- Purple particles
        print("🚀 DOPAMINE-COMBO: Streak " .. self.streakSystem.comboStreak .. " - Level completed with both goals!")
    end
    
    -- Record last celebration time
    self.streakSystem.lastCelebrationTime = currentTime
end

-- Update win condition to trigger dopamine feedback
function Game:onLevelComplete()
    local screenCenter = {x = love.graphics.getWidth()/2, y = love.graphics.getHeight()/2}
    
    -- Check what was completed for specific feedback
    local territoryComplete = currentTerritoryPercentage >= targetPercentage
    local shapeComplete = shapeChallenge.active and shapeChallenge.currentAccuracy >= shapeChallenge.targetShapeAccuracy
    
    if territoryComplete and shapeComplete then
        self:triggerDopamineFeedback("combo", screenCenter)
    elseif territoryComplete then
        self:triggerDopamineFeedback("territory", screenCenter)
    elseif shapeComplete then
        self:triggerDopamineFeedback("shape", screenCenter)
    end
end

    -- Check win/lose conditions
    self:checkGameConditions()
end

function Game:updateEnemies(dt)
    for i, enemy in ipairs(Enemies) do
        if enemy.update then
            -- DYNAMIC DIFFICULTY: React to player state
            local aggressionMultiplier = enemy.aggressionLevel or 1.0
            
            if Player.isDrawing then
                -- Enemies become more aggressive when player is vulnerable
                enemy.targetPlayer = true
                enemy.aggressionMultiplier = aggressionMultiplier * 1.5
                
                -- Advanced enemies react specifically to drawing
                if enemy.reactsToDrawing and level >= 8 then
                    -- Try to intercept player's likely path
                    if enemy.canPredictMovement then
                        enemy.predictedPlayerPos = {
                            i = Player.i + (math.random(-2, 2)),
                            j = Player.j + (math.random(-2, 2))
                        }
                    end
                end
            else
                -- Normal behavior when player is safe
                enemy.targetPlayer = false
                enemy.aggressionMultiplier = aggressionMultiplier
            end
            
            -- TERRITORY PRESSURE: Enemies become more aggressive as player succeeds
            local territoryPressure = currentTerritoryPercentage / 100.0
            if territoryPressure > 0.5 then
                -- Above 50% territory, enemies get 25% more aggressive
                enemy.aggressionMultiplier = (enemy.aggressionMultiplier or 1.0) * 1.25
            end
            if territoryPressure > 0.7 then
                -- Above 70% territory, enemies get another 25% boost
                enemy.aggressionMultiplier = (enemy.aggressionMultiplier or 1.0) * 1.25
            end
            
            -- SHAPE COMPLETION PRESSURE: React to shape progress
            if shapeChallenge.active and shapeChallenge.currentAccuracy > 60 then
                -- When player is close to completing shape, enemies rush
                enemy.aggressionMultiplier = (enemy.aggressionMultiplier or 1.0) * 1.3
            end
            
            -- COORDINATION: High-level enemies coordinate attacks
            if enemy.coordinatesWithOthers and level >= 12 then
                local nearbyEnemies = 0
                for j, otherEnemy in ipairs(Enemies) do
                    if i ~= j then
                        local distance = math.abs(enemy.i - otherEnemy.i) + math.abs(enemy.j - otherEnemy.j)
                        if distance <= 5 then
                            nearbyEnemies = nearbyEnemies + 1
                        end
                    end
                end
                -- Bonus aggression when multiple enemies are near
                if nearbyEnemies >= 2 then
                    enemy.aggressionMultiplier = (enemy.aggressionMultiplier or 1.0) * 1.2
                end
            end
            
            enemy:update(dt, Grid, Player)
        end
    end
    
    -- DYNAMIC ENEMY SPAWNING: Spawn additional enemies based on progress
    enemySpawnTimer = enemySpawnTimer + dt
    if enemySpawnTimer >= enemySpawnDelay and #Enemies < 8 then
        -- Chance to spawn additional enemy increases with territory control
        local spawnChance = 0.1 + (currentTerritoryPercentage / 100.0) * 0.2 -- 10-30% chance
        if math.random() < spawnChance then
            self:spawnAdditionalEnemy()
            enemySpawnTimer = 0
            enemySpawnDelay = math.max(15, enemySpawnDelay - 1) -- Spawn faster over time, min 15s
        end
    end
end

-- Spawn additional enemy during gameplay for dynamic difficulty
function Game:spawnAdditionalEnemy()
    local EnemyTypes = require 'src.enemy.init'
    
    -- Choose enemy type based on current level
    local enemyType = 'Chaser' -- Default
    if level <= 3 then
        enemyType = math.random() < 0.5 and 'Chaser' or 'Reclaimer'
    elseif level <= 7 then
        local types = {'Chaser', 'Reclaimer', 'Jammer'}
        enemyType = types[math.random(1, #types)]
    else
        local types = {'Chaser', 'Reclaimer', 'Jammer', 'GuardianBreaker', 'Phaser'}
        enemyType = types[math.random(1, #types)]
    end
    
    -- Find spawn position away from player
    local spawnI, spawnJ
    local attempts = 0
    repeat
        spawnI = math.random(2, Grid.width - 1)
        spawnJ = math.random(2, Grid.height - 1)
        local distFromPlayer = math.abs(spawnI - Player.i) + math.abs(spawnJ - Player.j)
        attempts = attempts + 1
    until (not Grid:isClaimed(spawnI, spawnJ) and distFromPlayer >= 8) or attempts > 30
    
    -- Create the enemy
    local enemy = nil
    if enemyType == 'Chaser' and EnemyTypes.Chaser then
        enemy = EnemyTypes.Chaser:new(spawnI, spawnJ, level)
    elseif enemyType == 'Reclaimer' and EnemyTypes.Reclaimer then
        enemy = EnemyTypes.Reclaimer:new(spawnI, spawnJ, level)
    elseif enemyType == 'Jammer' and EnemyTypes.Jammer then
        enemy = EnemyTypes.Jammer:new(spawnI, spawnJ, level)
    elseif enemyType == 'GuardianBreaker' and EnemyTypes.GuardianBreaker then
        enemy = EnemyTypes.GuardianBreaker:new(spawnI, spawnJ)
        enemy.level = level
    elseif enemyType == 'Phaser' and EnemyTypes.Phaser then
        enemy = EnemyTypes.Phaser:new(spawnI, spawnJ)
        enemy.level = level
    else
        enemy = EnemyTypes.Chaser:new(spawnI, spawnJ, level)
    end
    
    if enemy then
        -- Apply difficulty scaling
        enemy.level = level
        enemy.baseSpeed = enemy.moveDelay or 0.5
        local speedMultiplier = math.max(0.6, 1.0 - (level * 0.03))
        enemy.moveDelay = enemy.baseSpeed * speedMultiplier
        enemy.aggressionLevel = math.min(2.0, 1.0 + (level * 0.08))
        
        table.insert(Enemies, enemy)
        print("⚡ Dynamic spawn:", enemyType, "at level", level)
    end
end

function Game:checkCollisions()
    -- ✅ SAFE BORDER SYSTEM: Player is safe on border or claimed territory
    local playerI, playerJ = Player.i, Player.j
    local isOnBorder = (playerI == 1 or playerI == Grid.nodeWidth or playerJ == 1 or playerJ == Grid.nodeHeight)
    local isOnClaimed = false
    local isInSafeZone = false
    
    -- Check if player is on claimed territory
    if Grid.cells[playerI] and Grid.cells[playerI][playerJ] then
        isOnClaimed = (Grid.cells[playerI][playerJ] == 'claimed')
    end
    
    -- Check two-cell safety ring around border
    if not isOnBorder and not isOnClaimed then
        -- Check if within 2 cells of border
        local distToBorder = math.min(
            playerI - 1,                    -- Distance to left border
            Grid.nodeWidth - playerI,       -- Distance to right border
            playerJ - 1,                    -- Distance to top border
            Grid.nodeHeight - playerJ       -- Distance to bottom border
        )
        isInSafeZone = (distToBorder <= 1)
    end
    
    local playerIsSafe = isOnBorder or isOnClaimed or isInSafeZone
    
    if playerIsSafe then
        print("SAFE-ON-BORDER: true")
    end
    
    -- Player vs Enemy collisions - only if player is NOT safe
    for i, enemy in ipairs(Enemies) do
        if enemy.i and enemy.j then
            local distance = math.sqrt((Player.i - enemy.i)^2 + (Player.j - enemy.j)^2)
            if distance < 1.5 then
                if playerIsSafe then
                    print("ENEMY-IGNORED: " .. (enemy.type or "unknown") .. "_" .. i)
                else
                    self:playerHit()
                    break
                end
            end
        end
    end
end

function Game:playerHit()
    livesRemaining = livesRemaining - 1
    
    -- Reset player position
    Player.i = 1
    Player.j = math.floor(Grid.nodeHeight / 2)
    Player.isDrawing = false
    if Player.clearTrail then
        Player:clearTrail(Grid)
    end
    
    print("Player hit! Lives remaining:", livesRemaining)
end

function Game:calculateTerritoryPercentage()
    -- Use Grid's built-in calculation method for consistency
    local percentage = Grid:getClaimedPercent() * 100
    return percentage
end

function Game:checkGameConditions()
    -- Check individual completions
    local territoryComplete = currentTerritoryPercentage >= targetPercentage
    local shapeComplete = shapeChallenge.active and shapeChallenge.currentAccuracy >= shapeChallenge.targetShapeAccuracy
    
    -- ✅ ENHANCED Multiple Shape Completion Detection & Bonus System
    if shapeComplete and not self._lastShapeComplete then
        self._lastShapeComplete = true
        shapeChallenge.completedShapes = shapeChallenge.completedShapes + 1
        
        -- ✅ DOPAMINE FEEDBACK - Trigger shape completion celebration
        local playerPos = {x = Player.x, y = Player.y}
        self:triggerDopamineFeedback("shape", playerPos)
        
        -- Track same shape completions for additional multiplier
        local currentShapeType = shapeChallenge.currentTemplate and shapeChallenge.currentTemplate.type or "unknown"
        shapeChallenge.sameShapeCount = shapeChallenge.sameShapeCount or {}
        shapeChallenge.sameShapeCount[currentShapeType] = (shapeChallenge.sameShapeCount[currentShapeType] or 0) + 1
        
        -- Calculate same-shape multiplier bonus
        local sameShapeMultiplier = 1.0 + ((shapeChallenge.sameShapeCount[currentShapeType] - 1) * 0.5)  -- 1.0x, 1.5x, 2.0x, 2.5x...
        
        -- Detect perfect shapes (95%+ accuracy)
        if shapeChallenge.currentAccuracy >= 95 then
            shapeChallenge.perfectShapes = shapeChallenge.perfectShapes + 1
            print("🌟 PERFECT " .. string.upper(currentShapeType) .. "! (Perfect #" .. shapeChallenge.perfectShapes .. ", " .. currentShapeType .. " #" .. shapeChallenge.sameShapeCount[currentShapeType] .. ")")
        else
            print("✓ " .. string.upper(currentShapeType) .. " completed! (Shape #" .. shapeChallenge.completedShapes .. ", " .. currentShapeType .. " #" .. shapeChallenge.sameShapeCount[currentShapeType] .. ")")
        end
        
        -- Display multiplier information for repeated shapes
        if shapeChallenge.sameShapeCount[currentShapeType] > 1 then
            print("🔥 SAME SHAPE BONUS: " .. string.format("%.1f", sameShapeMultiplier) .. "x multiplier for multiple " .. currentShapeType .. "s!")
        end
        
        -- Fast completion bonus (consecutive shapes within 15 seconds)
        if gameTime - shapeChallenge.lastCompletionTime < 15 then
            shapeChallenge.fastCompletionBonus = shapeChallenge.fastCompletionBonus + 200 * shapeChallenge.completedShapes
            print("⚡ SPEED BONUS! +" .. (200 * shapeChallenge.completedShapes) .. " points")
        end
        shapeChallenge.lastCompletionTime = gameTime
        
        -- Enhanced shape multiplier: increases with each completion AND same-shape bonus
        shapeChallenge.shapeMultiplier = (1.0 + (shapeChallenge.completedShapes * 0.25)) * sameShapeMultiplier
        print("🎯 TOTAL SHAPE MULTIPLIER: " .. string.format("%.2f", shapeChallenge.shapeMultiplier) .. "x")
        
        -- Shape Master bonus (3+ perfect shapes)
        if shapeChallenge.perfectShapes >= 3 and not shapeChallenge.shapeMasterBonus then
            shapeChallenge.shapeMasterBonus = true
            totalScore = totalScore + 1500
            print("🏆 SHAPE MASTER BONUS! +1500 points (3+ perfect shapes)")
        end
        
        -- FIXED: DON'T change shape type during level - only reset accuracy for next attempt
        shapeChallenge.currentAccuracy = 0
        shapeChallenge.timeElapsed = 0
        
        print("🎯 CONTINUE WITH SAME SHAPE: " .. (shapeChallenge.currentTemplate.type or "square") .. " (Multiplier: " .. string.format("%.2f", shapeChallenge.shapeMultiplier) .. "x)")
    elseif not shapeComplete then
        self._lastShapeComplete = false
    end
    
    -- Check win condition: BOTH territory target AND shape accuracy requirement met
    local shapeAccuracyMet = shapeChallenge.active and shapeChallenge.currentAccuracy >= shapeChallenge.targetShapeAccuracy
    
    -- SUCCESS FEEDBACK: Both objectives complete!
    if territoryComplete and shapeAccuracyMet then
        -- Trigger success effects if not already done
        if not self._successTriggered then
            self._successTriggered = true
            self._successFlashTimer = 0.8  -- Green flash duration
            self._successMessageTimer = 3.0  -- Success message duration
            self._levelCompleteDelay = 1.5  -- 1.5 second delay before SPACE works
            
            -- ✅ DOPAMINE FEEDBACK - Trigger celebration based on completion type
            local screenCenter = {x = love.graphics.getWidth()/2, y = love.graphics.getHeight()/2}
            if territoryComplete and shapeAccuracyMet then
                self:triggerDopamineFeedback("combo", screenCenter)
            elseif territoryComplete then
                self:triggerDopamineFeedback("territory", screenCenter)
            elseif shapeAccuracyMet then
                self:triggerDopamineFeedback("shape", screenCenter)
            end
            
            -- ✅ WIN CONDITION LOGGING
            print("WIN: territory=" .. math.floor(currentTerritoryPercentage) .. "% shape=" .. math.floor(shapeChallenge.currentAccuracy) .. "%")
            
            -- Calculate final bonus based on multiple shapes
            local shapeBonus = shapeChallenge.completedShapes * 500 * shapeChallenge.shapeMultiplier
            local perfectBonus = shapeChallenge.perfectShapes * 300
            local totalShapeBonus = math.floor(shapeBonus + perfectBonus + shapeChallenge.fastCompletionBonus)
            
            if shapeChallenge.shapeMasterBonus then
                totalShapeBonus = totalShapeBonus + 1000
            end
            
            totalScore = totalScore + totalShapeBonus
            
            print("🎉 LEVEL COMPLETE!")
            print("   Territory: " .. math.floor(currentTerritoryPercentage) .. "%")
            print("   Shapes: " .. shapeChallenge.completedShapes .. " (" .. shapeChallenge.perfectShapes .. " perfect)")
            print("   Total Shape Bonus: +" .. totalShapeBonus .. " points")
            
            -- COMPREHENSIVE ACHIEVEMENT TRACKING
            local achievementData = {
                levelCompleted = true,
                level = level,
                territoryPercent = currentTerritoryPercentage,
                shapeAccuracy = shapeChallenge.currentAccuracy,
                character = Player.character and Player.character.name or "Architect",
                livesRemaining = livesRemaining,
                shapesDrawn = shapeChallenge.completedShapes,
                perfectShapes = shapeChallenge.perfectShapes,
                perfectShapesThisLevel = shapeChallenge.perfectShapes,
                shapeType = shapeChallenge.currentTemplate and shapeChallenge.currentTemplate.type,
                playTime = gameTime,
                zonesClosed = 1, -- At least one zone was closed to complete level
                enemiesDefeated = 0 -- Track if enemies were defeated by zone closure
            }
            
            Achievements:checkAchievements(achievementData)
            
            -- Color the filled area with success color
            self:highlightSuccessArea()
        end
        
        -- Check if success effects are done, then complete level
        if self._successFlashTimer and self._successFlashTimer <= 0 and 
           self._successMessageTimer and self._successMessageTimer <= 0 then
            gameWon = true
            
            -- ✅ AUTOMATIC LEVEL PROGRESSION AFTER 2 SECONDS
            if not self._autoProgressTimer then
                self._autoProgressTimer = 2.0  -- 2 second delay for automatic progression
                print("🚀 Level will auto-advance in 2 seconds (or press SPACE now)")
            end
        end
    elseif livesRemaining <= 0 then
        gameOver = true
        print("Game Over!")
    end
    
    -- Display progress messages (fixed)
    if territoryComplete and not shapeAccuracyMet then
        if not self._territoryCompleteNotified then
            print("Territory objective complete! Now focus on matching the target shape.")
            self._territoryCompleteNotified = true
        end
    elseif shapeAccuracyMet and not territoryComplete then
        if not self._shapeCompleteNotified then
            print("Shape objective complete! Now capture more territory to reach " .. targetPercentage .. "%.")
            self._shapeCompleteNotified = true
        end
    end
end

-- Add success area highlighting
function Game:highlightSuccessArea()
    -- Mark recently claimed cells with success color for visual feedback
    Grid._successHighlightTimer = 2.0
    Grid._successHighlightCells = {}
    
    -- Find all claimed cells to highlight
    for i = 2, Grid.width - 1 do
        for j = 2, Grid.height - 1 do
            if Grid:isClaimed(i, j) then
                table.insert(Grid._successHighlightCells, {i = i, j = j})
            end
        end
    end
end

function Game:draw()
    -- ✅ CELEBRATION SCREEN FLASH EFFECT
    if self._screenFlashTimer and self._screenFlashTimer > 0 then
        local flashAlpha = self._screenFlashTimer / 0.5  -- Fade from full to zero
        love.graphics.setColor(1, 1, 0.3, flashAlpha * 0.3)  -- Golden flash
        love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end
    
    -- Draw grid first
    Grid:draw()
    
    -- ✅ DRAW SHAPE DRAWING PATH - CRITICAL FOR VISUAL FEEDBACK
    if DrawPathSystem then
        DrawPathSystem:draw(Grid)
    end
    
    -- ✅ ENHANCED CELEBRATION EFFECTS OVERLAY
    if self._celebrationTimer and self._celebrationTimer > 0 then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        
        -- Sparkle effect for first-time success
        if self._sparkleEffect then
            local sparkleCount = 15
            for i = 1, sparkleCount do
                local angle = (i / sparkleCount) * 2 * math.pi + (self._sparkleTime or 0) * 2
                local radius = 100 + 50 * math.sin((self._sparkleTime or 0) * 3)
                local x = screenWidth * 0.5 + math.cos(angle) * radius
                local y = screenHeight * 0.5 + math.sin(angle) * radius
                
                local sparkleAlpha = math.max(0, self._celebrationTimer / 3.0)
                love.graphics.setColor(1, 1, 0.3, sparkleAlpha)
                love.graphics.circle('fill', x, y, 3 + 2 * math.sin((self._sparkleTime or 0) * 5 + i))
            end
        end
        
        -- Pulse effect for repeat success
        if self._pulseEffect then
            local pulseScale = 1.0 + 0.3 * math.sin((self._pulseTime or 0) * 8)
            local pulseAlpha = math.max(0, self._celebrationTimer / 1.5)
            love.graphics.setColor(0.2, 1.0, 0.8, pulseAlpha * 0.3)
            
            love.graphics.push()
            love.graphics.translate(screenWidth * 0.5, screenHeight * 0.5)
            love.graphics.scale(pulseScale)
            love.graphics.circle('line', 0, 0, 80)
            love.graphics.circle('line', 0, 0, 120)
            love.graphics.pop()
        end
    end
    
    -- Draw player
    Player:draw(Grid)
    
    -- Draw enemies
    for _, enemy in ipairs(Enemies) do
        if enemy.draw then
            enemy:draw(Grid)
        end
    end
    
    -- Draw HUD
    self:drawGameHUD()
    
    -- SUCCESS FEEDBACK VISUALS
    -- Draw success screen flash
    if self._successFlashTimer and self._successFlashTimer > 0 then
        local alpha = self._successFlashTimer / 0.8
        love.graphics.setColor(0.2, 1.0, 0.2, 0.3 * alpha)
        love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    -- ✅ ENHANCED SHAPE DRAWING FEEDBACK WITH ANIMATIONS
    if shapeDrawingFeedback.active and shapeDrawingFeedback.timer > 0 then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        
        -- Calculate fade-in effect
        local maxTimer = 4.0  -- Maximum timer for any feedback type
        local fadeAlpha = math.min(1.0, shapeDrawingFeedback.timer / 0.5)  -- Fade in quickly
        
        -- Position feedback in center-upper area
        local feedbackY = screenHeight * 0.15
        local feedbackWidth = 600
        local feedbackHeight = 80
        local feedbackX = (screenWidth - feedbackWidth) / 2
        
        -- Different visual styles based on feedback type
        if shapeDrawingFeedback.type == "first_success" then
            -- FIRST SUCCESS - MAXIMUM CELEBRATION
            local bounce = 1.0 + 0.2 * math.sin(love.timer.getTime() * 8)
            local glow = 0.5 + 0.3 * math.sin(love.timer.getTime() * 4)
            
            -- Glowing background
            love.graphics.setColor(1.0, 0.8, 0.1, fadeAlpha * glow * 0.8)
            love.graphics.rectangle('fill', feedbackX - 20, feedbackY - 20, feedbackWidth + 40, feedbackHeight + 40, 15, 15)
            
            -- Main background
            love.graphics.setColor(0.9, 0.7, 0.1, fadeAlpha * 0.95)
            love.graphics.rectangle('fill', feedbackX, feedbackY, feedbackWidth, feedbackHeight, 12, 12)
            
            -- Border
            love.graphics.setColor(1.0, 1.0, 0.3, fadeAlpha)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle('line', feedbackX, feedbackY, feedbackWidth, feedbackHeight, 12, 12)
            love.graphics.setLineWidth(1)
            
            -- Text with bounce effect
            love.graphics.push()
            love.graphics.translate(screenWidth / 2, feedbackY + feedbackHeight / 2)
            love.graphics.scale(bounce)
            love.graphics.setColor(1.0, 1.0, 1.0, fadeAlpha)
            local font = love.graphics.newFont(24)
            love.graphics.setFont(font)
            love.graphics.printf(shapeDrawingFeedback.message, -feedbackWidth/2, -12, feedbackWidth, 'center')
            love.graphics.pop()
            
        elseif shapeDrawingFeedback.type == "repeat_success" then
            -- REPEAT SUCCESS - ENCOURAGING GLOW
            local pulse = 1.0 + 0.1 * math.sin(love.timer.getTime() * 6)
            
            -- Background
            love.graphics.setColor(0.1, 0.8, 0.6, fadeAlpha * 0.9)
            love.graphics.rectangle('fill', feedbackX, feedbackY, feedbackWidth, feedbackHeight, 10, 10)
            
            -- Border with pulse
            love.graphics.setColor(0.2, 1.0, 0.8, fadeAlpha * pulse)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle('line', feedbackX, feedbackY, feedbackWidth, feedbackHeight, 10, 10)
            love.graphics.setLineWidth(1)
            
            -- Text
            love.graphics.setColor(1.0, 1.0, 1.0, fadeAlpha)
            local font = love.graphics.newFont(20)
            love.graphics.setFont(font)
            love.graphics.printf(shapeDrawingFeedback.message, feedbackX, feedbackY + feedbackHeight / 2 - 10, feedbackWidth, 'center')
            
        elseif shapeDrawingFeedback.type == "close" then
            -- CLOSE ATTEMPT - ENCOURAGING
            love.graphics.setColor(0.8, 0.5, 0.1, fadeAlpha * 0.9)
            love.graphics.rectangle('fill', feedbackX, feedbackY, feedbackWidth, feedbackHeight, 8, 8)
            love.graphics.setColor(1.0, 0.8, 0.2, fadeAlpha)
            love.graphics.rectangle('line', feedbackX, feedbackY, feedbackWidth, feedbackHeight, 8, 8)
            love.graphics.setColor(1.0, 1.0, 1.0, fadeAlpha)
            local font = love.graphics.newFont(18)
            love.graphics.setFont(font)
            love.graphics.printf(shapeDrawingFeedback.message, feedbackX, feedbackY + feedbackHeight / 2 - 9, feedbackWidth, 'center')
            
        elseif shapeDrawingFeedback.type == "failure" then
            -- FAILURE - CONSTRUCTIVE FEEDBACK
            love.graphics.setColor(0.6, 0.1, 0.1, fadeAlpha * 0.9)
            love.graphics.rectangle('fill', feedbackX, feedbackY, feedbackWidth, feedbackHeight, 8, 8)
            love.graphics.setColor(1.0, 0.3, 0.3, fadeAlpha)
            love.graphics.rectangle('line', feedbackX, feedbackY, feedbackWidth, feedbackHeight, 8, 8)
            love.graphics.setColor(1.0, 1.0, 1.0, fadeAlpha)
            local font = love.graphics.newFont(18)
            love.graphics.setFont(font)
            love.graphics.printf(shapeDrawingFeedback.message, feedbackX, feedbackY + feedbackHeight / 2 - 9, feedbackWidth, 'center')
            
        elseif shapeDrawingFeedback.type == "blocked" then
            -- DRAWING BLOCKED - CLEAR INSTRUCTION
            local shake = 2 * math.sin(love.timer.getTime() * 12)  -- Shake effect
            
            love.graphics.setColor(0.7, 0.1, 0.1, fadeAlpha * 0.9)
            love.graphics.rectangle('fill', feedbackX + shake, feedbackY, feedbackWidth, feedbackHeight, 8, 8)
            love.graphics.setColor(1.0, 0.4, 0.4, fadeAlpha)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle('line', feedbackX + shake, feedbackY, feedbackWidth, feedbackHeight, 8, 8)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1.0, 1.0, 1.0, fadeAlpha)
            local font = love.graphics.newFont(20)
            love.graphics.setFont(font)
            love.graphics.printf(shapeDrawingFeedback.message, feedbackX + shake, feedbackY + feedbackHeight / 2 - 10, feedbackWidth, 'center')
            
        else
            -- DEFAULT - SIMPLE FEEDBACK
            love.graphics.setColor(0.3, 0.3, 0.3, fadeAlpha * 0.9)
            love.graphics.rectangle('fill', feedbackX, feedbackY, feedbackWidth, feedbackHeight, 8, 8)
            love.graphics.setColor(0.8, 0.8, 0.8, fadeAlpha)
            love.graphics.rectangle('line', feedbackX, feedbackY, feedbackWidth, feedbackHeight, 8, 8)
            love.graphics.setColor(1.0, 1.0, 1.0, fadeAlpha)
            local font = love.graphics.newFont(18)
            love.graphics.setFont(font)
            love.graphics.printf(shapeDrawingFeedback.message, feedbackX, feedbackY + feedbackHeight / 2 - 9, feedbackWidth, 'center')
        end
    end
    
    -- Shape completion feedback
    if self._shapeCompletionTimer and self._shapeCompletionTimer > 0 then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        
        -- Shape completion message
        love.graphics.setColor(0.2, 0.8, 1.0, 0.9)
        love.graphics.rectangle('fill', screenWidth * 0.25, screenHeight * 0.35, screenWidth * 0.5, 60, 10, 10)
        love.graphics.setColor(0.4, 1.0, 1.0, 1.0)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle('line', screenWidth * 0.25, screenHeight * 0.35, screenWidth * 0.5, 60, 10, 10)
        love.graphics.setLineWidth(1)
        
        -- Success text
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.newFont(20)
        love.graphics.setFont(font)
        love.graphics.printf("Shape Closed Successfully!", screenWidth * 0.25, screenHeight * 0.35 + 20, screenWidth * 0.5, 'center')
        
        -- Reset font
        love.graphics.setFont(love.graphics.newFont(16))
    end
    
    -- Draw ability effects
    PanicPulse:draw()
    ZoneMirror:draw()
    
    -- Minimal achievement notifications (only show completion achievements)
    if gameWon then
        Achievements:drawNotifications()
    end
    
    -- Draw tutorial overlay
    Tutorial:draw()
    
    -- Draw game over screen
    if gameOver then
        self:drawGameOverScreen()
    elseif gameWon then
        self:drawWinScreen()
    end
end

function Game:drawGameHUD()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- ✅ MODERN UI CONSTANTS
    local margin = 20
    local fontSize = 16  -- Minimum 14pt for mobile
    local smallFontSize = 14
    local largeFontSize = 20
    
    -- Helper function for modern text with shadow
    local function drawModernText(text, x, y, size, color)
        local font = love.graphics.newFont(size or fontSize)
        love.graphics.setFont(font)
        
        -- Soft shadow
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.print(text, x + 1, y + 1)
        
        -- Main text
        love.graphics.setColor(color or {1, 1, 1, 1})
        love.graphics.print(text, x, y)
    end
    
    -- Helper function for modern capsule background
    local function drawCapsule(x, y, width, height, bgColor, borderColor)
        love.graphics.setColor(bgColor or {0.1, 0.1, 0.15, 0.9})
        love.graphics.rectangle('fill', x, y, width, height, height/2, height/2)
        
        if borderColor then
            love.graphics.setColor(borderColor)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle('line', x, y, width, height, height/2, height/2)
            love.graphics.setLineWidth(1)
        end
    end
    
    -- ✅ LEFT PANEL: Lives / Enemies / Time, Territory, Shape, Score
    local leftPanelX = margin
    local leftPanelY = margin
    local leftPanelWidth = 300
    local panelHeight = 32
    local spacing = 12
    
    local currentY = leftPanelY
    
    -- Lives / Enemies / Time Row
    drawCapsule(leftPanelX, currentY, leftPanelWidth, panelHeight, {0.15, 0.05, 0.05, 0.9}, {0.8, 0.2, 0.2, 0.8})
    drawModernText("Lives: " .. livesRemaining .. "   Enemies: " .. #Enemies .. "   Time: " .. math.floor(gameTime) .. "s", 
                   leftPanelX + 15, currentY + 6, fontSize, {1, 0.9, 0.9, 1})
    currentY = currentY + panelHeight + spacing
    
    -- Territory Bar
    local territoryComplete = currentTerritoryPercentage >= targetPercentage
    local territoryColor = territoryComplete and {0.2, 0.8, 0.2, 0.9} or {0.8, 0.4, 0.1, 0.9}
    local territoryBorderColor = territoryComplete and {0.4, 1, 0.4, 1} or {1, 0.7, 0.2, 1}
    
    drawCapsule(leftPanelX, currentY, leftPanelWidth, panelHeight, territoryColor, territoryBorderColor)
    drawModernText("Territory: " .. math.floor(currentTerritoryPercentage) .. "% / " .. targetPercentage .. "%", 
                   leftPanelX + 15, currentY + 6, fontSize)
    
    -- Territory progress bar
    local barWidth = leftPanelWidth - 30
    local barHeight = 6
    local barY = currentY + panelHeight - 10
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle('fill', leftPanelX + 15, barY, barWidth, barHeight, 3, 3)
    love.graphics.setColor(territoryBorderColor)
    love.graphics.rectangle('fill', leftPanelX + 15, barY, (currentTerritoryPercentage/100) * barWidth, barHeight, 3, 3)
    
    currentY = currentY + panelHeight + spacing
    
    -- Shape Accuracy Bar
    local shapeComplete = shapeChallenge.active and shapeChallenge.currentAccuracy >= shapeChallenge.targetShapeAccuracy
    local shapeColor = shapeComplete and {0.5, 0.2, 0.8, 0.9} or {0.3, 0.3, 0.6, 0.9}
    local shapeBorderColor = shapeComplete and {0.8, 0.4, 1, 1} or {0.6, 0.6, 0.9, 1}
    
    drawCapsule(leftPanelX, currentY, leftPanelWidth, panelHeight, shapeColor, shapeBorderColor)
    drawModernText("Shape: " .. math.floor(shapeChallenge.currentAccuracy or 0) .. "% / " .. shapeChallenge.targetShapeAccuracy .. "%", 
                   leftPanelX + 15, currentY + 6, fontSize)
    
    -- Shape accuracy progress bar
    local shapeBarY = currentY + panelHeight - 10
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle('fill', leftPanelX + 15, shapeBarY, barWidth, barHeight, 3, 3)
    love.graphics.setColor(shapeBorderColor)
    love.graphics.rectangle('fill', leftPanelX + 15, shapeBarY, (shapeChallenge.currentAccuracy/100) * barWidth, barHeight, 3, 3)
    
    currentY = currentY + panelHeight + spacing
    
    -- Total Score
    drawCapsule(leftPanelX, currentY, leftPanelWidth, panelHeight, {0.5, 0.4, 0.1, 0.9}, {1, 0.8, 0.3, 1})
    drawModernText("💎 Total Score: " .. totalScore, leftPanelX + 15, currentY + 6, fontSize, {1, 1, 0.7, 1})
    
    currentY = currentY + panelHeight + spacing * 2
    
    -- Status Messages
    if territoryComplete and shapeComplete then
        drawCapsule(leftPanelX, currentY, leftPanelWidth, panelHeight, {0.1, 0.6, 0.1, 0.9}, {0.3, 1, 0.3, 1})
        drawModernText("🎉 LEVEL COMPLETE! Press SPACE", leftPanelX + 15, currentY + 6, fontSize, {0.8, 1, 0.8, 1})
    elseif territoryComplete then
        drawCapsule(leftPanelX, currentY, leftPanelWidth, panelHeight + 20, {0.6, 0.3, 0.1, 0.9}, {1, 0.6, 0.2, 1})
        drawModernText("Territory complete! Match shape!", leftPanelX + 15, currentY + 6, fontSize, {1, 0.9, 0.7, 1})
        drawModernText("Press Q to start/stop drawing", leftPanelX + 15, currentY + 24, smallFontSize, {0.9, 0.8, 0.6, 1})
    elseif shapeComplete then
        drawCapsule(leftPanelX, currentY, leftPanelWidth, panelHeight, {0.6, 0.3, 0.1, 0.9}, {1, 0.6, 0.2, 1})
        drawModernText("Shape complete! Capture territory!", leftPanelX + 15, currentY + 6, fontSize, {1, 0.9, 0.7, 1})
    else
        -- ✅ ONLY SHOW DRAWING INSTRUCTION WHEN TERRITORY IS SUFFICIENT
        if territoryComplete then
            drawCapsule(leftPanelX, currentY, leftPanelWidth, panelHeight, {0.3, 0.3, 0.3, 0.9}, {0.6, 0.6, 0.6, 1})
            drawModernText("Press Q to draw shapes", leftPanelX + 15, currentY + 6, fontSize, {0.9, 0.9, 0.9, 1})
        else
            local needed = targetPercentage - currentTerritoryPercentage
            drawCapsule(leftPanelX, currentY, leftPanelWidth, panelHeight, {0.3, 0.3, 0.3, 0.9}, {0.6, 0.6, 0.6, 1})
            drawModernText("Capture " .. math.ceil(needed) .. "% more territory first", leftPanelX + 15, currentY + 6, smallFontSize, {0.8, 0.8, 0.8, 1})
        end
    end
    
    currentY = currentY + panelHeight + spacing * 2
    
    -- ✅ DOPAMINE FEEDBACK - Streak Display
    if self.streakSystem.territoryStreak > 0 or self.streakSystem.shapeStreak > 0 or self.streakSystem.comboStreak > 0 then
        local streakHeight = panelHeight + 10
        drawCapsule(leftPanelX, currentY, leftPanelWidth, streakHeight, {0.1, 0.1, 0.3, 0.9}, {0.4, 0.4, 0.8, 1})
        
        local streakText = "🔥 STREAKS: "
        if self.streakSystem.comboStreak > 0 then
            streakText = streakText .. "Combo " .. self.streakSystem.comboStreak .. " "
        end
        if self.streakSystem.territoryStreak > 0 then
            streakText = streakText .. "Territory " .. self.streakSystem.territoryStreak .. " "
        end
        if self.streakSystem.shapeStreak > 0 then
            streakText = streakText .. "Shape " .. self.streakSystem.shapeStreak
        end
        
        drawModernText(streakText, leftPanelX + 15, currentY + 6, fontSize, {1, 0.8, 0.3, 1})
        currentY = currentY + streakHeight + spacing
    end
    
    -- Character info
    local characterName = Player.character and Player.character.name or "Unknown"
    drawCapsule(leftPanelX, currentY, leftPanelWidth, panelHeight, {0.2, 0.3, 0.5, 0.9}, {0.4, 0.6, 0.8, 1})
    drawModernText("Character: " .. characterName, leftPanelX + 15, currentY + 6, fontSize, {0.7, 0.9, 1, 1})
    
    -- ✅ CENTERED LEVEL INFO
    local centerX = screenWidth / 2
    local topY = 10
    
    -- Level indicator
    drawCapsule(centerX - 100, topY, 200, 36, {0.1, 0.2, 0.4, 0.9}, {0.3, 0.5, 0.8, 1})
    drawModernText("LEVEL " .. level .. " / 50", centerX - 70, topY + 8, largeFontSize, {0.8, 0.9, 1, 1})
    
    -- Territory and Shape status
    local statusY = topY + 50
    local statusText = "Territory: " .. math.floor(currentTerritoryPercentage) .. "% | Shape: " .. math.floor(shapeChallenge.currentAccuracy or 0) .. "%"
    local statusWidth = 300
    drawCapsule(centerX - statusWidth/2, statusY, statusWidth, 28, {0.05, 0.05, 0.1, 0.8}, {0.3, 0.3, 0.5, 0.8})
    drawModernText(statusText, centerX - statusWidth/2 + 15, statusY + 4, fontSize, {0.9, 0.9, 0.9, 1})
end
    love.graphics.rectangle('line', hudX - 15, hudY - 15, 320, screenHeight - 60, 12, 12)
    love.graphics.setLineWidth(1)
    
    -- Game title with clean level display
    local titleFont = love.graphics.newFont(22)
    love.graphics.setFont(titleFont)
    drawTextWithShadow("VOIDLINE", hudX, hudY, {0.4, 0.8, 1.0, 1})
    hudY = hudY + 30
    
    -- Remove shape info from left panel - moving to right panel
    
    -- Divider line
    love.graphics.setColor(0.3, 0.5, 0.8, 0.6)
    love.graphics.line(hudX, hudY, hudX + 260, hudY)
    hudY = hudY + 15
    
    -- ESSENTIAL GAME INFO (Clean and minimal)
    font = love.graphics.newFont(16)
    love.graphics.setFont(font)
    
    drawTextWithShadow("Lives: " .. livesRemaining, hudX, hudY, {1, 0.8, 0.2, 1})
    hudY = hudY + lineHeight
    
    drawTextWithShadow("Enemies: " .. #Enemies, hudX, hudY, {1, 0.4, 0.4, 1})
    hudY = hudY + lineHeight
    
    drawTextWithShadow("Time: " .. math.floor(gameTime) .. "s", hudX, hudY, {0.8, 1, 0.8, 1})
    hudY = hudY + lineHeight + 15
    
    -- Territory objective with progress bar
    local territoryComplete = currentTerritoryPercentage >= targetPercentage
    local territoryColor = territoryComplete and {0.2, 1.0, 0.2, 1} or {0.2, 0.6, 1.0, 1}
    local territoryText = "Territory: " .. math.floor(currentTerritoryPercentage) .. "% / " .. targetPercentage .. "%" .. (territoryComplete and " ✓" or "")
    drawTextWithShadow(territoryText, hudX, hudY, territoryColor)
    hudY = hudY + lineHeight + 3
    
    -- Territory progress bar
    local barWidth = 220
    love.graphics.setColor(0.2, 0.2, 0.3, 0.9)
    love.graphics.rectangle('fill', hudX, hudY, barWidth, 14, 7, 7)
    love.graphics.setColor(territoryColor[1], territoryColor[2], territoryColor[3], 0.9)
    love.graphics.rectangle('fill', hudX, hudY, (currentTerritoryPercentage/100) * barWidth, 14, 7, 7)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.rectangle('line', hudX, hudY, barWidth, 14, 7, 7)
    hudY = hudY + 25
    
    -- Shape challenge objective with progress bar
    if shapeChallenge.active then
        local shapeComplete = shapeChallenge.currentAccuracy >= shapeChallenge.targetShapeAccuracy
        local shapeColor = shapeComplete and {0.2, 1.0, 0.2, 1} or {0.8, 0.6, 1.0, 1}
        
        local shapeText = "Shape Match: " .. math.floor(shapeChallenge.currentAccuracy) .. "% / " .. shapeChallenge.targetShapeAccuracy .. "%" .. (shapeComplete and " ✓" or "")
        drawTextWithShadow(shapeText, hudX, hudY, shapeColor)
        hudY = hudY + lineHeight + 3
        
        -- Shape accuracy progress bar
        love.graphics.setColor(0.2, 0.2, 0.3, 0.9)
        love.graphics.rectangle('fill', hudX, hudY, barWidth, 14, 7, 7)
        love.graphics.setColor(shapeColor[1], shapeColor[2], shapeColor[3], 0.9)
        love.graphics.rectangle('fill', hudX, hudY, (shapeChallenge.currentAccuracy/100) * barWidth, 14, 7, 7)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.rectangle('line', hudX, hudY, barWidth, 14, 7, 7)
        hudY = hudY + 25
    end
    
    -- Clean status messages (minimal)
    local territoryComplete = currentTerritoryPercentage >= targetPercentage
    local shapeComplete = shapeChallenge.active and shapeChallenge.currentAccuracy >= shapeChallenge.targetShapeAccuracy
    
    if territoryComplete and shapeComplete then
        love.graphics.setColor(0.1, 0.7, 0.1, 0.9)
        love.graphics.rectangle('fill', hudX - 5, hudY, 270, 30, 8, 8)
        love.graphics.setColor(0.2, 1.0, 0.2, 0.8)
        love.graphics.rectangle('line', hudX - 5, hudY, 270, 30, 8, 8)
        drawTextWithShadow("🎉 LEVEL COMPLETE! Press SPACE", hudX + 5, hudY + 8, {0.2, 1.0, 0.2, 1})
        hudY = hudY + 40
    elseif not territoryComplete then
        drawTextWithShadow("Capture territory to unlock shape drawing", hudX, hudY, {0.9, 0.9, 0.9, 0.7})
        hudY = hudY + lineHeight + 5
    else
        drawTextWithShadow("Press Q to draw shapes", hudX, hudY, {0.9, 0.9, 0.9, 1})
        hudY = hudY + lineHeight + 5
    end
    
    -- Switch to regular font for stats
    font = love.graphics.newFont(16)
    love.graphics.setFont(font)
    
    -- Game stats with proper spacing and colors
    drawTextWithShadow("Lives: " .. livesRemaining, hudX, hudY, {1, 0.8, 0.2, 1})
    hudY = hudY + lineHeight
    
    drawTextWithShadow("Enemies: " .. #Enemies, hudX, hudY, {1, 0.4, 0.4, 1})
    hudY = hudY + lineHeight
    
    drawTextWithShadow("Time: " .. math.floor(gameTime) .. "s", hudX, hudY, {0.8, 1, 0.8, 1})
    hudY = hudY + lineHeight + 10
    
    -- Territory stats with progress bar
    local territoryComplete = currentTerritoryPercentage >= targetPercentage
    local territoryColor = territoryComplete and {0.2, 1.0, 0.2, 1} or {0.2, 0.6, 1.0, 1}
    local territoryText = "Territory: " .. math.floor(currentTerritoryPercentage) .. "% / " .. targetPercentage .. "%" .. (territoryComplete and " ✓" or "")
    drawTextWithShadow(territoryText, hudX, hudY, territoryColor)
    hudY = hudY + lineHeight + 3
    
    -- Territory progress bar with better sizing
    local barWidth = 220
    love.graphics.setColor(0.2, 0.2, 0.3, 0.9)
    love.graphics.rectangle('fill', hudX, hudY, barWidth, 14, 7, 7)
    love.graphics.setColor(territoryColor[1], territoryColor[2], territoryColor[3], 0.9)
    love.graphics.rectangle('fill', hudX, hudY, (currentTerritoryPercentage/100) * barWidth, 14, 7, 7)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.rectangle('line', hudX, hudY, barWidth, 14, 7, 7)
    hudY = hudY + 22
    
    drawTextWithShadow("Territory Score: " .. territoryScore, hudX, hudY, {0.6, 0.9, 1, 1})
    hudY = hudY + lineHeight + 10
    
    -- Shape challenge stats with progress bar
    local shapeComplete = shapeChallenge.active and shapeChallenge.currentAccuracy >= shapeChallenge.targetShapeAccuracy
    local shapeColor = shapeComplete and {0.2, 1.0, 0.2, 1} or {0.8, 0.6, 1.0, 1}
    drawTextWithShadow("Shape Score: " .. shapeScore, hudX, hudY, shapeColor)
    hudY = hudY + lineHeight
    
    if shapeChallenge.active then
        local shapeText = "Shape Accuracy: " .. math.floor(shapeChallenge.currentAccuracy) .. "% / " .. shapeChallenge.targetShapeAccuracy .. "%" .. (shapeComplete and " ✓" or "")
        drawTextWithShadow(shapeText, hudX, hudY, shapeColor)
        hudY = hudY + lineHeight + 3
        
        -- Shape accuracy progress bar
        love.graphics.setColor(0.2, 0.2, 0.3, 0.9)
        love.graphics.rectangle('fill', hudX, hudY, barWidth, 14, 7, 7)
        love.graphics.setColor(shapeColor[1], shapeColor[2], shapeColor[3], 0.9)
        love.graphics.rectangle('fill', hudX, hudY, (shapeChallenge.currentAccuracy/100) * barWidth, 14, 7, 7)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.rectangle('line', hudX, hudY, barWidth, 14, 7, 7)
        hudY = hudY + 25
    end
    
    -- Status messages with enhanced background boxes
    if territoryComplete and shapeComplete then
        love.graphics.setColor(0.1, 0.7, 0.1, 0.9)
        love.graphics.rectangle('fill', hudX - 8, hudY - 8, 280, 30, 8, 8)
        love.graphics.setColor(0.2, 1.0, 0.2, 0.8)
        love.graphics.rectangle('line', hudX - 8, hudY - 8, 280, 30, 8, 8)
        drawTextWithShadow("🎉 LEVEL COMPLETE! Press SPACE", hudX, hudY, {0.2, 1.0, 0.2, 1})
        hudY = hudY + lineHeight + 15
    elseif territoryComplete then
        love.graphics.setColor(0.7, 0.5, 0.1, 0.9)
        love.graphics.rectangle('fill', hudX - 8, hudY - 8, 280, 50, 8, 8)
        love.graphics.setColor(1.0, 1.0, 0.2, 0.8)
        love.graphics.rectangle('line', hudX - 8, hudY - 8, 280, 50, 8, 8)
        drawTextWithShadow("Territory complete! Match shape!", hudX, hudY, {1.0, 1.0, 0.2, 1})
        hudY = hudY + lineHeight
        drawTextWithShadow("Press Q to start/stop drawing", hudX, hudY, {0.9, 0.9, 0.9, 1})
        hudY = hudY + lineHeight + 15
    elseif shapeComplete then
        love.graphics.setColor(0.7, 0.5, 0.1, 0.9)
        love.graphics.rectangle('fill', hudX - 8, hudY - 8, 280, 30, 8, 8)
        love.graphics.setColor(1.0, 1.0, 0.2, 0.8)
        love.graphics.rectangle('line', hudX - 8, hudY - 8, 280, 30, 8, 8)
        drawTextWithShadow("Shape complete! Capture territory!", hudX, hudY, {1.0, 1.0, 0.2, 1})
        hudY = hudY + lineHeight + 15
    else
        -- ✅ ONLY SHOW DRAWING INSTRUCTION WHEN TERRITORY IS SUFFICIENT
        if territoryComplete then
            drawTextWithShadow("Press Q to draw shapes", hudX, hudY, {0.9, 0.9, 0.9, 1})
            hudY = hudY + lineHeight + 5
        else
            -- Show territory progress instead
            local needed = targetPercentage - currentTerritoryPercentage
            drawTextWithShadow("Capture " .. math.ceil(needed) .. "% more territory first", hudX, hudY, {0.8, 0.8, 0.8, 1})
            hudY = hudY + lineHeight + 5
        end
    end
    
    -- Total score with emphasis
    love.graphics.setColor(0.5, 0.4, 0.1, 0.9)
    love.graphics.rectangle('fill', hudX - 8, hudY - 8, 220, 30, 8, 8)
    love.graphics.setColor(1, 1, 0.3, 0.8)
    love.graphics.rectangle('line', hudX - 8, hudY - 8, 220, 30, 8, 8)
    drawTextWithShadow("💎 Total Score: " .. totalScore, hudX, hudY, {1, 1, 0.3, 1})
    hudY = hudY + lineHeight + 10
    
    -- Character info
    local characterName = Player.character and Player.character.name or "Unknown"
    drawTextWithShadow("Character: " .. characterName, hudX, hudY, {0.6, 0.8, 1, 1})
    hudY = hudY + lineHeight + 5
    
    -- RIGHT PANEL: TARGET SHAPE INFO - POSITIONED TO AVOID OVERLAP
    local rightPanelX = screenWidth - 350  -- Moved further right
    local rightPanelY = 20
    
    -- TARGET SHAPE PANEL (Top Priority)
    local currentShape = shapeChallenge.currentTemplate
    if currentShape then
        -- Shape info background
        love.graphics.setColor(0.1, 0.3, 0.6, 0.9)
        love.graphics.rectangle('fill', rightPanelX, rightPanelY, 300, 120, 10, 10)
        love.graphics.setColor(0.2, 0.6, 1.0, 1)
        love.graphics.rectangle('line', rightPanelX, rightPanelY, 300, 120, 10, 10)
        
        -- Title
        love.graphics.setColor(1, 1, 1, 1)
        local titleFont = love.graphics.newFont(18)
        love.graphics.setFont(titleFont)
        drawTextWithShadow("TARGET SHAPE", rightPanelX + 15, rightPanelY + 10, {0.8, 1.0, 1.0, 1})
        
        -- Level and shape info
        local font16 = love.graphics.newFont(16)
        love.graphics.setFont(font16)
        
        drawTextWithShadow("LEVEL " .. level .. " / 50", rightPanelX + 15, rightPanelY + 35, {0.2, 1.0, 1.0, 1})
        drawTextWithShadow("Target: " .. (currentShape.name or "Unknown"), rightPanelX + 15, rightPanelY + 55, {0.8, 1.0, 0.8, 1})
        drawTextWithShadow("Required Accuracy: " .. (currentShape.requiredAccuracy or 80) .. "%", rightPanelX + 15, rightPanelY + 75, {1.0, 0.8, 0.6, 1})
        drawTextWithShadow("Difficulty: " .. (currentShape.difficulty or 1) .. "/9", rightPanelX + 15, rightPanelY + 95, {1.0, 0.6, 0.8, 1})
    end
    
    -- Enhanced Drawing mode indicator (moved down)
    local drawingPanelWidth = 180
    local drawingPanelHeight = 40
    local drawingPanelX = rightPanelX
    local drawingPanelY = rightPanelY + 140  -- Below target shape panel
    
    -- ABILITIES UI PANEL
    local abilitiesY = drawingPanelY + 50
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', drawingPanelX - 10, abilitiesY, 200, 80, 8, 8)
    love.graphics.setColor(0.8, 0.6, 1.0, 1)
    love.graphics.rectangle('line', drawingPanelX - 10, abilitiesY, 200, 80, 8, 8)
    
    -- Abilities title
    drawTextWithShadow("⚡ ABILITIES", drawingPanelX, abilitiesY + 5, {0.8, 0.6, 1.0, 1})
    
    -- Draw ability buttons
    PanicPulse:drawUI(drawingPanelX, abilitiesY + 25)
    ZoneMirror:drawUI(drawingPanelX, abilitiesY + 55)
    
    -- SHAPE FEEDBACK PANEL
    if shapeChallenge.currentFeedback and shapeChallenge.feedbackTimer and shapeChallenge.feedbackTimer > 0 then
        local feedbackY = abilitiesY + 90
        local alpha = math.min(1.0, shapeChallenge.feedbackTimer / 2.0)
        
        love.graphics.setColor(0.1, 0.5, 0.8, alpha * 0.9)
        love.graphics.rectangle('fill', drawingPanelX - 10, feedbackY, 200, 40, 8, 8)
        love.graphics.setColor(0.3, 0.7, 1.0, alpha)
        love.graphics.rectangle('line', drawingPanelX - 10, feedbackY, 200, 40, 8, 8)
        
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.printf("💡 " .. shapeChallenge.currentFeedback, drawingPanelX - 5, feedbackY + 8, 190, 'center')
    end
    
    -- Drawing mode shows ON when shape challenge is active OR actively drawing
    if Player.isDrawing or (shapeChallenge.active and shapeChallenge.currentAccuracy < shapeChallenge.targetShapeAccuracy) then
        -- Animated green border when drawing mode active
        local pulse = 0.8 + 0.2 * math.sin(love.timer.getTime() * 4)
        love.graphics.setColor(0.1, 0.8, 0.1, pulse)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle('line', drawingPanelX, drawingPanelY, drawingPanelWidth, drawingPanelHeight, 8, 8)
        love.graphics.setLineWidth(1)
        
        love.graphics.setColor(0.1, 0.6, 0.1, 0.9)
        love.graphics.rectangle('fill', drawingPanelX, drawingPanelY, drawingPanelWidth, drawingPanelHeight, 8, 8)
        
        if Player.isDrawing then
            drawTextWithShadow("🎨 DRAWING MODE: ON", drawingPanelX + 10, drawingPanelY + 12, {0.2, 1.0, 0.2, 1})
        else
            drawTextWithShadow("🎯 SHAPE MODE: READY", drawingPanelX + 10, drawingPanelY + 12, {0.2, 1.0, 0.2, 1})
        end
    else
        love.graphics.setColor(0.3, 0.3, 0.3, 0.7)
        love.graphics.rectangle('fill', drawingPanelX, drawingPanelY, drawingPanelWidth, drawingPanelHeight, 8, 8)
        love.graphics.setColor(0.6, 0.6, 0.6, 0.8)
        love.graphics.rectangle('line', drawingPanelX, drawingPanelY, drawingPanelWidth, drawingPanelHeight, 8, 8)
        
        if shapeChallenge.active and shapeChallenge.currentAccuracy >= shapeChallenge.targetShapeAccuracy then
            drawTextWithShadow("✅ SHAPE COMPLETE!", drawingPanelX + 10, drawingPanelY + 12, {0.2, 1.0, 0.2, 1})
        else
            drawTextWithShadow("⏸️ DRAWING MODE: OFF", drawingPanelX + 10, drawingPanelY + 12, {0.8, 0.8, 0.8, 1})
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    
    -- ✅ DOPAMINE FEEDBACK - Draw celebration particles 
    self:drawCelebrationParticles()
    
    -- Draw shape challenge minimap - ALWAYS draw it, even if no template
    self:drawShapeChallengeMap()
end

function Game:drawShapeChallengeMap()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- ✅ TARGET MINI-MAP WITH STARS (Top-right, non-overlapping)
    local mapSize = 120
    local mapX = screenWidth - mapSize - 30
    local mapY = 100
    
    -- Draw circular mini-map background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
    love.graphics.circle('fill', mapX + mapSize/2, mapY + mapSize/2, mapSize/2)
    
    -- Draw border
    love.graphics.setColor(0.4, 0.6, 0.9, 1)
    love.graphics.setLineWidth(3)
    love.graphics.circle('line', mapX + mapSize/2, mapY + mapSize/2, mapSize/2)
    love.graphics.setLineWidth(1)
    
    -- Draw target shape inside circle
    local currentShape = shapeChallenge.currentTemplate
    if currentShape then
        local centerX, centerY = mapX + mapSize/2, mapY + mapSize/2
        local shapeSize = mapSize * 0.6
        
        love.graphics.setColor(0.8, 0.9, 1, 0.8)
        love.graphics.setLineWidth(2)
        
        if currentShape.type == "triangle" then
            -- Draw triangle
            local h = shapeSize * 0.4
            local points = {
                centerX, centerY - h,           -- top
                centerX - h * 0.866, centerY + h/2,  -- bottom left
                centerX + h * 0.866, centerY + h/2   -- bottom right
            }
            love.graphics.polygon('line', points)
            
        elseif currentShape.type == "square" then
            -- Draw square
            local size = shapeSize * 0.35
            love.graphics.rectangle('line', centerX - size, centerY - size, size * 2, size * 2)
            
        elseif currentShape.type == "circle" then
            -- Draw circle
            love.graphics.circle('line', centerX, centerY, shapeSize * 0.3)
            
        else
            -- Default shape
            love.graphics.circle('line', centerX, centerY, shapeSize * 0.25)
        end
        
        love.graphics.setLineWidth(1)
    end
    
    -- ✅ STAR DISPLAY (up to 5 stars above the ring)
    local shapeSuccessCount = shapeChallenge.completedShapes or 0
    local starCount = math.min(5, shapeSuccessCount)
    
    if starCount > 0 then
        local starY = mapY - 25
        local starSpacing = 20
        local startX = mapX + mapSize/2 - (starCount - 1) * starSpacing / 2
        
        for i = 1, starCount do
            local starX = startX + (i - 1) * starSpacing
            
            -- Star animation (pop effect)
            local scale = 1.0
            if shapeChallenge._lastStarTime and love.timer.getTime() - shapeChallenge._lastStarTime < 0.5 then
                scale = 1.0 + 0.3 * math.sin((love.timer.getTime() - shapeChallenge._lastStarTime) * 10)
            end
            
            love.graphics.setColor(1, 1, 0.3, 1)
            love.graphics.print("⭐", starX - 8 * scale, starY - 8 * scale, 0, scale, scale)
        end
    end
    
    -- Mini-map label
    love.graphics.setColor(0.9, 0.9, 1, 1)
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.print("TARGET SHAPE", mapX - 10, mapY + mapSize + 10)
    
    -- Goal info
    love.graphics.setFont(love.graphics.newFont(12))
    local goalText = "Goal: " .. (currentShape and currentShape.requiredAccuracy or 80) .. "% accuracy"
    love.graphics.print(goalText, mapX - 5, mapY + mapSize + 30)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Game:drawGameOverScreen()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Semi-transparent overlay
    love.graphics.setColor(0.5, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, screenWidth, screenHeight)
    
    -- Title
    love.graphics.setColor(1, 0.2, 0.2, 1)
    love.graphics.printf("GAME OVER", 0, screenHeight * 0.3, screenWidth, 'center')
    
    -- Final score
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Final Score: " .. totalScore, 0, screenHeight * 0.45, screenWidth, 'center')
    love.graphics.printf("Level Reached: " .. level, 0, screenHeight * 0.5, screenWidth, 'center')
    
    -- Restart instruction
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf("Press R to restart or ESC to return to menu", 0, screenHeight * 0.6, screenWidth, 'center')
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Game:drawWinScreen()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0.5, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, screenWidth, screenHeight)
    
    -- Clean completion screen with detailed reasons
    local centerX = screenWidth / 2
    
    -- Title
    love.graphics.setColor(0.2, 1, 0.2, 1)
    local titleFont = love.graphics.newFont(28)
    love.graphics.setFont(titleFont)
    love.graphics.printf("🎉 LEVEL " .. level .. " COMPLETE!", 0, screenHeight * 0.25, screenWidth, 'center')
    
    -- DETAILED RESULTS - Show WHY the level completed
    local font18 = love.graphics.newFont(18)
    love.graphics.setFont(font18)
    
    -- Territory result
    local territoryResult = currentTerritoryPercentage >= targetPercentage
    love.graphics.setColor(territoryResult and {0.2, 1.0, 0.2, 1} or {1.0, 0.6, 0.2, 1})
    local territoryText = territoryResult and "✅ Territory Objective Achieved (" .. math.floor(currentTerritoryPercentage) .. "% / " .. targetPercentage .. "%)" or "⚠️ Territory: " .. math.floor(currentTerritoryPercentage) .. "% / " .. targetPercentage .. "%"
    love.graphics.printf(territoryText, 0, screenHeight * 0.35, screenWidth, 'center')
    
    -- Shape result
    local shapeResult = shapeChallenge.currentAccuracy >= shapeChallenge.targetShapeAccuracy
    love.graphics.setColor(shapeResult and {0.2, 1.0, 0.2, 1} or {1.0, 0.6, 0.2, 1})
    local shapeText = shapeResult and "✅ Shape Objective Achieved (" .. math.floor(shapeChallenge.currentAccuracy) .. "% / " .. shapeChallenge.targetShapeAccuracy .. "%)" or "❌ Shape Not Accurate Enough (" .. math.floor(shapeChallenge.currentAccuracy) .. "% / " .. shapeChallenge.targetShapeAccuracy .. "%)"
    love.graphics.printf(shapeText, 0, screenHeight * 0.4, screenWidth, 'center')
    
    -- Level completion explanation
    if territoryResult and shapeResult then
        love.graphics.setColor(0.8, 1, 0.8, 1)
        love.graphics.printf("Both objectives completed - Level won!", 0, screenHeight * 0.46, screenWidth, 'center')
    end
    
    -- Score
    love.graphics.setColor(1, 1, 0.3, 1)
    love.graphics.printf("Total Score: " .. totalScore, 0, screenHeight * 0.5, screenWidth, 'center')
    
    -- Next level preview
    if level < 50 then
        local nextShape = ShapeTemplates:getShapeForLevel(level + 1)
        if nextShape then
            love.graphics.setColor(0.7, 0.9, 1, 1)
            love.graphics.printf("Next: Level " .. (level + 1) .. " - " .. (nextShape.name or "Unknown"), 0, screenHeight * 0.58, screenWidth, 'center')
        end
        
        -- Continue instruction with delay
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        if self._levelCompleteDelay and self._levelCompleteDelay > 0 then
            love.graphics.printf("Calculating results... " .. math.ceil(self._levelCompleteDelay) .. "s", 0, screenHeight * 0.7, screenWidth, 'center')
        else
            love.graphics.printf("Press SPACE to continue", 0, screenHeight * 0.7, screenWidth, 'center')
        end
    else
        love.graphics.setColor(1, 0.8, 0.2, 1)
        love.graphics.printf("🏁 ALL 50 LEVELS COMPLETE! 🏁", 0, screenHeight * 0.58, screenWidth, 'center')
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        if self._levelCompleteDelay and self._levelCompleteDelay > 0 then
            love.graphics.printf("Final results... " .. math.ceil(self._levelCompleteDelay) .. "s", 0, screenHeight * 0.7, screenWidth, 'center')
        else
            love.graphics.printf("Press SPACE to return to menu", 0, screenHeight * 0.7, screenWidth, 'center')
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Game:keypressed(key)
    -- Tutorial handles ESC for skipping
    if Tutorial:keypressed(key) then
        return
    end
    
    if gameOver then
        if key == 'r' then
            self:initializeGame()
            gameOver = false
        elseif key == 'escape' then
            local Gamestate = require 'hump.gamestate'
            local Menu = require 'src.ui.menu'
            Gamestate.switch(Menu)
        end
    elseif gameWon then
        if key == 'space' and (not self._levelCompleteDelay or self._levelCompleteDelay <= 0) then
            -- Check if all 50 levels are complete
            if level >= 50 then
                -- Return to main menu after completing all levels
                local Gamestate = require 'hump.gamestate'
                local Menu = require 'src.ui.menu'
                Gamestate.switch(Menu)
            else
                -- Advance to next level with proper reset
                level = level + 1
                print("🚀 ADVANCING TO LEVEL " .. level)
                
                -- Reset all game state for new level
                self:initializeGame()
                gameWon = false
                gameOver = false
                
                -- Clear any lingering feedback
                shapeDrawingFeedback.active = false
                self._successTriggered = false
                self._shapeJustCompleted = false
                
                print("✅ Level " .. level .. " initialized with shape: " .. (shapeChallenge.currentTemplate and shapeChallenge.currentTemplate.name or "Unknown"))
            end
        end
    else
        -- In-game controls
        if key == 'q' then
            -- ✅ ENHANCED DRAWING RESTRICTIONS - STRICTLY ENFORCED
            local territoryComplete = currentTerritoryPercentage >= targetPercentage
            
            if DrawPathSystem.isDrawing then
                -- Player is already drawing - finish the drawing
                local completedPath = DrawPathSystem:finishDrawing()
                print("🎯 Finished drawing shape")
                
                -- ✅ TRIGGER FINAL SHAPE ANALYSIS IMMEDIATELY AFTER FINISHING
                if completedPath and #completedPath.points >= 3 and shapeChallenge.active then
                    print("🔍 FINAL ANALYSIS: Analyzing completed shape...")
                    -- Force final shape analysis with completed path
                    local currentTemplate = shapeChallenge.currentTemplate
                    if currentTemplate then
                        -- Create player path for final matching
                        local playerPath = { points = {} }
                        local screenWidth = love.graphics.getWidth()
                        local screenHeight = love.graphics.getHeight()
                        
                        for _, point in ipairs(completedPath.points) do
                            local x = point.x / screenWidth
                            local y = point.y / screenHeight
                            table.insert(playerPath.points, {x = x, y = y})
                        end
                        
                        local matchResult = ShapeMatcher:matchShape(playerPath, currentTemplate)
                        local finalAccuracy = (matchResult.accuracy or 0) * 100
                        
                        -- Apply bonuses like the regular system
                        local shapeType = currentTemplate.type or "triangle"
                        if shapeType == "triangle" then
                            local corners = self:detectCornersFromPath(completedPath.points)
                            if #corners >= 2 and #corners <= 4 then
                                finalAccuracy = finalAccuracy + 15
                            end
                            if self:isPathClosedFromPoints(completedPath.points) then
                                finalAccuracy = finalAccuracy + 15
                            end
                        end
                        
                        shapeChallenge.currentAccuracy = math.max(0, math.min(100, finalAccuracy))
                        print("🎯 FINAL SHAPE ACCURACY:", math.floor(shapeChallenge.currentAccuracy), "%")
                    end
                end
            elseif territoryComplete then
                -- Territory requirement met - allow drawing
                local playerX, playerY = Grid:getNodePixelPosition(Player.i, Player.j)
                DrawPathSystem:startDrawing(playerX, playerY)
                print("✏️ Started drawing shape (Territory: " .. math.floor(currentTerritoryPercentage) .. "%)")
                
                -- Clear any previous shape feedback
                shapeDrawingFeedback.active = false
                shapeChallenge.currentAccuracy = 0
                
            else
                -- BLOCK DRAWING - Territory requirement not met
                local shortfall = targetPercentage - currentTerritoryPercentage
                
                shapeDrawingFeedback.active = true
                shapeDrawingFeedback.message = "🚫 CAPTURE " .. targetPercentage .. "% TERRITORY FIRST! (Need " .. math.ceil(shortfall) .. "% more)"
                shapeDrawingFeedback.timer = 3.0
                shapeDrawingFeedback.color = {1.0, 0.4, 0.4, 1}
                shapeDrawingFeedback.type = "blocked"
                
                print("❌ DRAWING BLOCKED: Must capture " .. targetPercentage .. "% territory first (Currently " .. math.floor(currentTerritoryPercentage) .. "%)")
                
                -- Visual indication that drawing is blocked
                self._drawingBlockedFlash = 1.0  -- Flash effect duration
            end
        elseif key == 'p' then
            -- Activate Panic Pulse ability
            if PanicPulse:canActivate() then
                PanicPulse:activate(Player, Enemies, Grid)
                Tutorial:onAbilityUsed()  -- Notify tutorial
            else
                print("❌ Panic Pulse not available")
            end
        elseif key == 'm' then
            -- Activate Zone Mirror ability
            if ZoneMirror:canActivate() then
                ZoneMirror:activate(Player, Grid)
                Tutorial:onAbilityUsed()  -- Notify tutorial
            else
                print("❌ Zone Mirror not available")
            end
        end
    end
end

return Game
