-- src/player.lua
-- Handles player input, movement, trail creation, hitbox logic, and all speed modifiers via getCurrentSpeed()

local love = require "love" -- Added missing love require
local Player = {}
local Gamestate = require 'hump.gamestate' -- For accessing game state
local Grid = require('src.grid')

local function getCharacterByName(name)
    local characters = require('src.characters.init')
    for _, char in ipairs(characters) do
        if char.name == name then return char end
    end
    return characters[1] -- fallback to first
end

---
-- Loads the player with the given grid and character.
-- @param grid The grid object
-- @param character The character table (optional)
function Player:load(grid, character)
    -- Initialize player with given character
    -- Player position is now node-based. Nodes are 1 to grid.nodeWidth and 1 to grid.nodeHeight
    self.i = 1 -- Start on the first column of nodes (left border)
    self.j = math.floor(grid.nodeHeight / 2) -- Start at a middle node vertically

    -- Always use the selectedCharacter from Game if not explicitly passed
    if not character then
        if _G.selectedCharacter then
            character = getCharacterByName(_G.selectedCharacter.name)
        else
            character = getCharacterByName("Architect")
        end
    else
        character = getCharacterByName(character.name)
    end
    self.character = character
    self.moveDelay = 0.15 / (self.character.speed or 2.0) 
    self.moveTimer = 0 -- Ensure moveTimer is initialized
    self.dir = {x=0, y=0}
    self.trail = {} -- Trail is a list of node coordinates: { {i=node_i, j=node_j}, ... }
    self.isDrawing = false
    self.trailForDrawingLastClosure = nil -- ADDED: To hold trail for drawing after closure
    self.attemptingClosure = false -- ADDED: Flag for when closure is attempted this frame

    self.color = self.character.color or {0.2, 0.6, 1}
    self.trailColor = self.character.trailColor or {1, 0.8, 0.2}
    
    -- Character-specific initializations
    if self.character.name == "Trickster" then
        self.tricksterSwapTimer = 10 -- seconds (this is the passive swap)
        self.tricksterDecoyActive = false
        self.tricksterDecoyTimer = 0 -- Duration of active decoy
        self.tricksterDecoyCooldownTimer = 0 -- Cooldown for the ability
        self.tricksterDecoyPosition = nil -- {i, j} for the decoy
        self.originalSpeed = self.character.speed -- Store original speed
    end
    if self.character.name == "Architect" then
        self.architectTrailPersistTimer = 0
        self.architectLastTrailCells = {} -- To store the trail if player stops drawing
    end

    -- Fuse mechanic properties
    self.isFuseActive = false
    self.fuseTimer = 0
    self.fuseDuration = (self.character.fuseDuration or 5)
    self.fuseDefuseAvailable = (self.character.fuseDefuse or false)
    self.fuseDefused = false
    self.fuseShieldActive = false
    self.fuseShieldCooldown = 0
    self.fuseShieldDuration = 2
    self.fuseShieldCooldownMax = 10

    -- Trickster specific: set default values if missing
    if self.character.name == "Trickster" then
        if not self.character.decoySpeedMultiplier then self.character.decoySpeedMultiplier = 1.25 end
        if not self.character.decoyDuration then self.character.decoyDuration = 2.5 end
        if not self.character.decoyCooldown then self.character.decoyCooldown = 8 end
    end

    Player.abilitiesUsed = 0
    Player._abilityFlashTimer = 0

    self.fadingTrails = {} -- List of {trail=table, timer=number}
end

---
-- Returns true if the given cell is claimed.
-- @param grid The grid object
-- @param i The cell's i index
-- @param j The cell's j index
local function isClaimed(grid, i, j)
    return grid.cells[i] and (grid.cells[i][j] == 'claimed')
end

---
-- Returns true if the given cell is part of the trail.
-- @param grid The grid object
-- @param i The cell's i index
-- @param j The cell's j index
local function isTrail(grid, i, j)
    return grid.cells[i] and (grid.cells[i][j] == 'trail')
end

---
-- Updates the player state (movement, abilities, fuse, etc).
-- @param dt Delta time
-- @param grid The grid object
function Player:update(dt, grid)
    if self.moveTimer == nil then -- Safeguard against nil moveTimer
        print("Warning: Player.moveTimer was nil, re-initializing to 0.")
        self.moveTimer = 0
    end

    -- ADDED: Clear attemptClose flag from previous frame
    if self.attemptingClosure then
        self.attemptingClosure = false
    end

    local game = Gamestate.current()

    -- Trickster Decoy Cooldown Update
    if self.character and self.character.name == "Trickster" then
        if self.tricksterDecoyCooldownTimer > 0 then
            self.tricksterDecoyCooldownTimer = self.tricksterDecoyCooldownTimer - dt
        end
        if self.tricksterDecoyActive then
            self.tricksterDecoyTimer = self.tricksterDecoyTimer - dt
            if self.tricksterDecoyTimer <= 0 then
                self.tricksterDecoyActive = false
                self.tricksterDecoyPosition = nil
                self.character.speed = self.originalSpeed -- Restore speed
                -- Invisibility is handled in draw, but reset state here if needed
                do local ok, Config = pcall(require, 'src.config'); if ok and Config.debug and Config.debug.enabled then print("Trickster decoy expired") end end
            end
        end
    end

    -- Architect Trail Persistence Update
    if self.character and self.character.name == "Architect" and self.architectTrailPersistTimer > 0 then
        self.architectTrailPersistTimer = self.architectTrailPersistTimer - dt
        if self.architectTrailPersistTimer <= 0 then
            -- Trail expired, clear it from grid and player
            for _, cell_coord in ipairs(self.architectLastTrailCells) do
                if grid.cells[cell_coord.i] and grid.cells[cell_coord.i][cell_coord.j] == 'trail' then
                    grid.cells[cell_coord.i][cell_coord.j] = 'empty'
                end
            end
            self.architectLastTrailCells = {}
            if not self.isDrawing then -- Only fully stop drawing if not actively drawing a new trail
                self.trail = {}
            end
            -- print("Architect trail expired")
        end
    end

    -- Guardian: activate fuse shield (press F)
    if self.character and self.character.name == "Guardian" then
        if love.keyboard.isDown('f') and not self.fuseShieldActive and self.fuseShieldCooldown <= 0 then
            self.fuseShieldActive = true
            self.fuseShieldCooldown = self.fuseShieldCooldownMax
            self.fuseShieldTimer = self.fuseShieldDuration
        end
        if self.fuseShieldActive then
            self.fuseShieldTimer = self.fuseShieldTimer - dt
            if self.fuseShieldTimer <= 0 then
                self.fuseShieldActive = false
            end
        end
        if self.fuseShieldCooldown > 0 then
            self.fuseShieldCooldown = self.fuseShieldCooldown - dt
        end
    end

    -- Fuse Mechanic Update
    if self.isFuseActive then
        -- בדיקה: האם השחקן חזר לשטח בטוח (קו גבול, תא claimed או תא island)
        local onBorder = (self.i == 1 or self.i == grid.width or self.j == 1 or self.j == grid.height)
        local onClaimed = (grid.cells[self.i] and (grid.cells[self.i][self.j] == 'claimed' or grid.cells[self.i][self.j] == 'island'))
        if onBorder or onClaimed then
            -- שרוף את ה-trail בלבד, השחקן שורד, פיוז מתאפס מיד
            if self.burningTrail then
                for _, node in ipairs(self.burningTrail) do
                    if grid.cells[node.i] and grid.cells[node.i][node.j] == 'trail' then
                        grid.cells[node.i][node.j] = 'empty'
                    end
                end
            end
            self.trail = {}
            self.isDrawing = false
            self.isFuseActive = false
            self.burningTrail = nil
        elseif self.fuseShieldActive then
            self.isFuseActive = false
            self.fuseTimer = 0
        else
            self.fuseTimer = self.fuseTimer - dt
            if self.fuseTimer <= 0 then
                -- פיוז נגמר: אם השחקן לא חזר לשטח, מוות
                self.isFuseActive = false
                self.fuseTimer = 0
                -- Use Gamestate instead of circular dependency
                local currentGame = Gamestate.current()
                if currentGame and currentGame.handleGameOver then
                    currentGame:handleGameOver()
                end
                self.fuseBurnFlash = 0.5
                if love.audio and self.fuseBurnSound then
                    love.audio.play(self.fuseBurnSound)
                end
            end
        end
    end

    -- Character-specific updates (like Trickster)
    if self.character and self.character.name == "Trickster" then
        self.tricksterSwapTimer = self.tricksterSwapTimer - dt
        if self.tricksterSwapTimer <= 0 then
            local enemies = grid.enemies -- Assuming enemies are accessible via grid
            if enemies and #enemies > 0 then
                local randomEnemy = enemies[math.random(#enemies)]
                -- Swap positions
                local tempI, tempJ = self.i, self.j
                self.i, self.j = randomEnemy.i, randomEnemy.j
                randomEnemy.i, randomEnemy.j = tempI, tempJ
                self.tricksterSwapTimer = 10 -- Reset timer
                 -- Ensure player is not swapped into a wall/obstacle if those exist
                if not grid:isInside(self.i, self.j) or (grid.cells[self.i] and grid.cells[self.i][self.j] == 'obstacle') then
                    -- Revert swap or find a safe nearby cell (simplified for now)
                    randomEnemy.i, randomEnemy.j = self.i, self.j -- Revert enemy position
                    self.i, self.j = tempI, tempJ -- Revert player position
                end
            end
        end
    end

    -- In Player:update, add jammed logic to disable abilities
    if self.isJammed then
        self.jamTimer = (self.jamTimer or 0) - dt
        -- Block fuse shield and other actives
        if self.jamTimer > 0 then
            self.fuseShieldActive = false
            -- Optionally block other actives here
        else
            self.isJammed = false
            self.jamTimer = 0
        end
    end

    -- Handle active ability cooldown (for characters with an active ability)
    if self.character and self.character.activateAbility then
        if not self.abilityCooldown then self.abilityCooldown = 0 end
        if self.abilityCooldown > 0 then
            self.abilityCooldown = math.max(0, self.abilityCooldown - dt)
        end
        -- Example: activate ability on keypress (space)
        if love.keyboard.isDown('space') and self.abilityCooldown <= 0 then
            if self.character.activateAbility then
                self.character:activateAbility(self, grid)
                self.abilityCooldown = self.character.activeAbilityCooldown or 8
            end
        end
    end

    -- Character-specific active abilities
    if self.character then
        -- Trickster: Decoy Swap (SPACE)
        if self.character.name == "Trickster" then
            if not self.tricksterDecoyCooldownTimer then self.tricksterDecoyCooldownTimer = 0 end
            if not self.tricksterDecoyActive then self.tricksterDecoyActive = false end
            if love.keyboard.isDown('space') and self.tricksterDecoyCooldownTimer <= 0 and not self.tricksterDecoyActive then
                self.tricksterDecoyActive = true
                self.tricksterDecoyTimer = self.character.decoyDuration or 2.5
                self.tricksterDecoyCooldownTimer = self.character.decoyCooldown or 8
                self.tricksterDecoyPosition = {i = self.i, j = self.j}
                -- self.speed = (self.character.speed or 2.8) * (self.character.decoySpeedMultiplier or 1.25)
            end
            if self.tricksterDecoyActive then
                self.tricksterDecoyTimer = self.tricksterDecoyTimer - dt
                if self.tricksterDecoyTimer <= 0 then
                    self.tricksterDecoyActive = false
                    self.tricksterDecoyPosition = nil
                    -- self.speed = self.character.speed or 2.8
                end
            end
            if self.tricksterDecoyCooldownTimer > 0 then
                self.tricksterDecoyCooldownTimer = self.tricksterDecoyCooldownTimer - dt
            end
        end
        -- Guardian: Defuse fuse once per run (F key to avoid WASD conflict)
        if self.character.name == "Guardian" then
            if not self.fuseDefused and love.keyboard.isDown('f') and self.isFuseActive then
                self.isFuseActive = false
                self.fuseTimer = 0
                self.fuseDefused = true
            end
        end
        -- Echo: Pulse trail to stun enemies (E)
        if self.character.name == "Echo" or self.character.name == "The Echo" then
            if not self.echoPulseCooldown then self.echoPulseCooldown = 0 end
            if love.keyboard.isDown('e') and self.echoPulseCooldown <= 0 then
                -- Stun all enemies near trail
                if grid and grid.enemies then
                    for _, enemy in ipairs(grid.enemies) do
                        for _, node in ipairs(self.trail) do
                            if math.abs(enemy.i - node.i) <= 1 and math.abs(enemy.j - node.j) <= 1 then
                                enemy.isStunned = true
                                enemy.stunTimer = 1.2
                            end
                        end
                    end
                end
                self.echoPulseCooldown = 7
            end
            if self.echoPulseCooldown > 0 then
                self.echoPulseCooldown = self.echoPulseCooldown - dt
            end
        end
        -- Sprinter: Dash (SHIFT)
        if self.character.name == "Sprinter" then
            if not self.sprinterDashCooldown then self.sprinterDashCooldown = 0 end
            if love.keyboard.isDown('lshift') and self.sprinterDashCooldown <= 0 then
                -- self.speed = (self.character.speed or 3.2) * 2.2
                self.sprinterDashTimer = 0.5
                self.sprinterDashCooldown = 5
            end
            if self.sprinterDashTimer and self.sprinterDashTimer > 0 then
                self.sprinterDashTimer = self.sprinterDashTimer - dt
                if self.sprinterDashTimer <= 0 then
                    self.speed = self.character.speed or 3.2
                    self.sprinterDashTimer = nil
                end
            end
            if self.sprinterDashCooldown > 0 then
                self.sprinterDashCooldown = self.sprinterDashCooldown - dt
            end
        end
        -- Scorer: No active, but double score for large closures (handled in game.lua)
    end

    self.moveTimer = self.moveTimer - dt
    if self.moveTimer <= 0 then
        -- Determine input direction (keyboard first; touch optional)
        local input_dx, input_dy = 0, 0
        if love.keyboard.isDown('left') or love.keyboard.isDown('a') then input_dx = -1 end
        if love.keyboard.isDown('right') or love.keyboard.isDown('d') then input_dx = 1 end
        if love.keyboard.isDown('up') or love.keyboard.isDown('w') then input_dy = -1 end
        if love.keyboard.isDown('down') or love.keyboard.isDown('s') then input_dy = 1 end

        -- Basic touch steering: move toward first touch (nearest axis)
        if input_dx == 0 and input_dy == 0 and love.touch and love.touch.getTouches then
            local touches = love.touch.getTouches()
            if touches and #touches > 0 then
                local tx, ty = love.touch.getPosition(touches[1])
                -- Player center in pixels
                local px = grid.offsetX + (self.i - 1) * grid.cellSize + grid.cellSize/2
                local py = grid.offsetY + (self.j - 1) * grid.cellSize + grid.cellSize/2
                local dx = tx - px
                local dy = ty - py
                if math.abs(dx) > math.abs(dy) then
                    input_dx = (dx > 0) and 1 or -1
                else
                    input_dy = (dy > 0) and 1 or -1
                end
            end
        end

        local dx_node, dy_node = 0, 0
        local moved = false

        -- Allow diagonal movement but prefer orthogonal for trail drawing
        if input_dx ~= 0 or input_dy ~= 0 then
            dx_node = input_dx
            dy_node = input_dy
            moved = true
        end

        if moved then
            local prev_node_i, prev_node_j = self.i, self.j
            local next_node_i, next_node_j = self.i + dx_node, self.j + dy_node

            -- ENHANCED: Prevent diagonal out-of-bounds movement
            -- Clamp movement to playable node area BEFORE any other checks
            next_node_i = math.max(1, math.min(grid.nodeWidth, next_node_i))
            next_node_j = math.max(1, math.min(grid.nodeHeight, next_node_j))

            -- Bounds checking (redundant but kept for safety)
            if next_node_i >= 1 and next_node_i <= grid.nodeWidth and 
               next_node_j >= 1 and next_node_j <= grid.nodeHeight then
                
                -- Check if moving into claimed territory or borders
                local onClaimedTerritory = false
                local onBorder = (next_node_i == 1 or next_node_i == grid.nodeWidth or 
                                 next_node_j == 1 or next_node_j == grid.nodeHeight)
                
                -- Convert node position to cell position for territory checking
                local cellI = math.min(next_node_i, grid.width)
                local cellJ = math.min(next_node_j, grid.height)
                if grid.cells[cellI] and grid.cells[cellI][cellJ] then
                    onClaimedTerritory = (grid.cells[cellI][cellJ] == 'claimed')
                end
                
                local lineIsSafe = onBorder or onClaimedTerritory

                if not self.isDrawing and not lineIsSafe then
                    -- Start drawing a new trail
                    self.isDrawing = true
                    self.trail = { {i=prev_node_i, j=prev_node_j}, {i=next_node_i, j=next_node_j} }
                    
                    -- Mark cells as trail for visual feedback
                    self:markTrailCells(grid)
                    
                    -- ✅ START DrawPath pipeline via Game state's instance (pixel coords)
                    local game = Gamestate.current()
                    if game and game.drawPath and game.drawPath.startPath then
                        local pixelX = grid.offsetX + (prev_node_i - 1) * grid.cellSize + grid.cellSize/2
                        local pixelY = grid.offsetY + (prev_node_j - 1) * grid.cellSize + grid.cellSize/2
                        game.drawPath:startPath(pixelX, pixelY)
                        local nextPixelX = grid.offsetX + (next_node_i - 1) * grid.cellSize + grid.cellSize/2
                        local nextPixelY = grid.offsetY + (next_node_j - 1) * grid.cellSize + grid.cellSize/2
                        game.drawPath:addPoint(nextPixelX, nextPixelY)
                    end
                    
                    local ok, Config = pcall(require, 'src.config')
                    if ok and Config.debug and Config.debug.enabled then print("Player started drawing trail") end
                elseif self.isDrawing and not lineIsSafe then
                    -- Continue drawing
                    table.insert(self.trail, {i=next_node_i, j=next_node_j})
                    
                    -- Update trail marking
                    self:markTrailCells(grid)
                    
                    -- ✅ ADD to DrawPath instance
                    local game = Gamestate.current()
                    if game and game.drawPath and game.drawPath.addPoint then
                        local pixelX = grid.offsetX + (next_node_i - 1) * grid.cellSize + grid.cellSize/2
                        local pixelY = grid.offsetY + (next_node_j - 1) * grid.cellSize + grid.cellSize/2
                        game.drawPath:addPoint(pixelX, pixelY)
                    end
                    
                    local ok2, Config2 = pcall(require, 'src.config')
                    if ok2 and Config2.debug and Config2.debug.enabled then print("Player continued trail") end
                elseif self.isDrawing and lineIsSafe then
                    -- Reached a safe area, attempt to close
                    table.insert(self.trail, {i=next_node_i, j=next_node_j})
                    
                    -- ✅ FINISH DrawPath instance
                    local game = Gamestate.current()
                    if game and game.drawPath and game.drawPath.finishPath then
                        local pixelX = grid.offsetX + (next_node_i - 1) * grid.cellSize + grid.cellSize/2
                        local pixelY = grid.offsetY + (next_node_j - 1) * grid.cellSize + grid.cellSize/2
                        game.drawPath:addPoint(pixelX, pixelY)
                        local drawData = game.drawPath:finishPath()
                        -- Evaluate shape on closure
                        if drawData and game.evaluateShapeDrawing then
                            game:evaluateShapeDrawing(drawData)
                        end
                    end
                    
                    local ok3, Config3 = pcall(require, 'src.config')
                    if ok3 and Config3.debug and Config3.debug.enabled then print("Attempting to close trail with", #self.trail, "points") end
                    
                    -- Convert node trail to cell trail for closing
                    local cellTrail = self:convertNodeTrailToCells()
                    if #cellTrail >= 3 then
                        local newlyClaimedCells = grid:closeArea(cellTrail)
                        do local ok4, Config4 = pcall(require, 'src.config'); if ok4 and Config4.debug and Config4.debug.enabled then print("Closed area with", newlyClaimedCells, "new cells") end end
                        
                        -- ENHANCED: Life Recovery on Large Territory Capture
                        if newlyClaimedCells >= 20 and _G.livesRemaining and _G.livesRemaining < 3 then
                            _G.livesRemaining = math.min(3, _G.livesRemaining + 1)
                            do local ok, Config = pcall(require, 'src.config'); if ok and Config.debug and Config.debug.enabled then print("LIFE RECOVERED! Large capture:", newlyClaimedCells, "cells. Lives:", _G.livesRemaining) end end
                            -- Show celebration toast
                            if _G.currentGame and _G.currentGame.toast then
                                _G.currentGame.toast.msg = "LIFE RECOVERED! ♥"
                                _G.currentGame.toast.timer = 2.5
                            end
                        elseif newlyClaimedCells >= 30 and _G.livesRemaining and _G.livesRemaining < 3 then
                            -- Extra large captures get bonus recovery chance
                            _G.livesRemaining = math.min(3, _G.livesRemaining + 1)
                            do local ok, Config = pcall(require, 'src.config'); if ok and Config.debug and Config.debug.enabled then print("BONUS LIFE! Massive capture:", newlyClaimedCells, "cells. Lives:", _G.livesRemaining) end end
                            if _G.currentGame and _G.currentGame.toast then
                                _G.currentGame.toast.msg = "BONUS LIFE! ♥♥"
                                _G.currentGame.toast.timer = 2.5
                            end
                        end
                        
                        -- ENHANCED SHAPE SUCCESS FEEDBACK with clearer validation
                        if _G.currentGame and newlyClaimedCells > 5 then  -- Lower threshold for better response
                            local territoryPercent = _G.currentGame:calculateTerritoryPercentage()
                            local shapeChallenge = _G.currentGame.shapeChallenge or {}
                            local territoryComplete = territoryPercent >= 75
                            local shapeAccuracy = shapeChallenge.currentAccuracy or 0
                            local shapeComplete = (shapeChallenge.active == true) and (shapeAccuracy >= 80)
                            
                            -- Show progress feedback for ANY meaningful area capture
                            do local ok, Config = pcall(require, 'src.config'); if ok and Config.debug and Config.debug.enabled then
                                if shapeAccuracy >= 60 then
                                    print("Good shape! Accuracy:", math.floor(shapeAccuracy), "% (need 80%)")
                                elseif shapeAccuracy >= 30 then
                                    print("Shape detected but needs improvement. Accuracy:", math.floor(shapeAccuracy), "%")
                                else
                                    print("Try drawing a more square-like shape. Current accuracy:", math.floor(shapeAccuracy), "%")
                                end
                            end end
                            
                            -- Only show ultimate success when BOTH objectives are met
                            if territoryComplete and shapeComplete then
                                _G.currentGame._shapeJustCompleted = true
                                _G.currentGame._shapeCompletionTimer = 3.0
                                do local ok, Config = pcall(require, 'src.config'); if ok and Config.debug and Config.debug.enabled then print("VICTORY! Shape AND Territory objectives completed!") end end
                            else
                                do local ok, Config = pcall(require, 'src.config'); if ok and Config.debug and Config.debug.enabled then print("Progress - Area:", newlyClaimedCells, "cells | Territory:", math.floor(territoryPercent), "% | Shape:", math.floor(shapeAccuracy), "%") end end
                            end
                        end
                    end
                    
                    -- Clear trail
                    self:clearTrail(grid)
                    self.isDrawing = false
                    
                    -- DrawPath instance is finished by game; no global cleanup needed
                elseif not self.isDrawing and lineIsSafe then
                    -- Moving in safe area, ensure no trail
                    if #self.trail > 0 then
                        self:clearTrail(grid)
                    end
                end

                -- Move player
                self.i, self.j = next_node_i, next_node_j
                self.moveTimer = self.moveDelay
            end
        end
    end

    -- Update fading trails
    self:updateFadingTrails(dt)
end

-- Helper function to mark trail cells in the grid (DISABLED to prevent blue dots)
function Player:markTrailCells(grid)
    -- Do nothing - let Player drawing system handle all trail visualization
    -- This prevents the blue dots from appearing in the grid
end

-- Helper function to clear trail from grid
function Player:clearTrail(grid)
    -- Clear trail cells from grid
    for i = 1, grid.width do
        for j = 1, grid.height do
            if grid.cells[i] and grid.cells[i][j] == 'trail' then
                grid.cells[i][j] = 'empty'
            end
        end
    end
    self.trail = {}
end

-- Helper function to convert node trail to cell trail
function Player:convertNodeTrailToCells()
    local cellTrail = {}
    for _, node in ipairs(self.trail) do
        local cellI = math.min(node.i, Grid.width or 60)
        local cellJ = math.min(node.j, Grid.height or 45)
        table.insert(cellTrail, {i = cellI, j = cellJ})
    end
    return cellTrail
end

-- Update fading trails
function Player:updateFadingTrails(dt)
    for i = #self.fadingTrails, 1, -1 do
        local t = self.fadingTrails[i]
        t.timer = t.timer - dt
        if t.timer <= 0 then 
            table.remove(self.fadingTrails, i) 
        end
    end
end

---
-- Draws the player, trail, and all visual effects.
-- @param grid The grid object
function Player:draw(grid)
    -- Draw fading trails
    for _, t in ipairs(self.fadingTrails) do
        if #t.trail >= 2 then
            local alpha = math.max(0, t.timer / 0.7)
            love.graphics.setColor(self.trailColor[1], self.trailColor[2], self.trailColor[3], 0.25 * alpha)
            love.graphics.setLineWidth(3)
            for k = 1, #t.trail - 1 do
                local p1_node = t.trail[k]
                local p2_node = t.trail[k+1]
                local x1, y1 = grid:getNodePixelPosition(p1_node.i, p1_node.j)
                local x2, y2 = grid:getNodePixelPosition(p2_node.i, p2_node.j)
                love.graphics.line(x1, y1, x2, y2)
            end
            love.graphics.setLineWidth(1)
        end
    end
    
    -- Draw CURRENT ACTIVE TRAIL while drawing (single unified trail)
    if self.isDrawing and self.trail and #self.trail >= 2 then
        -- Only draw ONE trail system - no duplicates
        love.graphics.setColor(1, 1, 0.2, 0.9)  -- Bright yellow for active drawing
        love.graphics.setLineWidth(4)
        for k = 1, #self.trail - 1 do
            local p1_node = self.trail[k]
            local p2_node = self.trail[k+1]
            local x1, y1 = grid:getNodePixelPosition(p1_node.i, p1_node.j)
            local x2, y2 = grid:getNodePixelPosition(p2_node.i, p2_node.j)
            love.graphics.line(x1, y1, x2, y2)
        end
        love.graphics.setLineWidth(1)
        
        -- Small trail dots only at key points to avoid clutter
        love.graphics.setColor(1, 0.8, 0, 1)
        local startNode = self.trail[1]
        local endNode = self.trail[#self.trail]
        if startNode then
            local x, y = grid:getNodePixelPosition(startNode.i, startNode.j)
            love.graphics.circle('fill', x, y, 4)  -- Start point
        end
        if endNode and #self.trail > 1 then
            local x, y = grid:getNodePixelPosition(endNode.i, endNode.j)
            love.graphics.circle('fill', x, y, 3)  -- End point
        end
    end
    
    if self.trailForDrawingLastClosure then self.trailForDrawingLastClosure = nil end

    -- Draw Trickster's Decoy (משולש)
    if self.character and self.character.name == "Trickster" and self.tricksterDecoyActive and self.tricksterDecoyPosition then
        local decoyColor = {self.color[1], self.color[2], self.color[3], 0.5}
        love.graphics.setColor(decoyColor)
        local x = grid.offsetX + (self.tricksterDecoyPosition.i-0.5)*grid.cellSize
        local y = grid.offsetY + (self.tricksterDecoyPosition.j-0.5)*grid.cellSize
        love.graphics.polygon('fill', x, y-18, x+16, y+14, x-16, y+14)
    end

    -- Draw player (unique shape per character - SINGLE REPRESENTATION ONLY)
    local px, py = grid:getNodePixelPosition(self.i, self.j)
    love.graphics.setColor(self.color)
    local cs = grid.cellSize
    if self.character and self.character.name then
        -- Drawing character with outline for clarity
        love.graphics.setLineWidth(2)
        if self.character.name == "Architect" then
            -- Architect: blue rounded square with white border (SINGLE SHAPE)
            love.graphics.setColor(1,1,1,0.9)
            love.graphics.rectangle('line', px-cs*0.20, py-cs*0.20, cs*0.40, cs*0.40, 8, 8)
            love.graphics.setColor(self.color)
            love.graphics.rectangle('fill', px-cs*0.18, py-cs*0.18, cs*0.36, cs*0.36, 6, 6)
        elseif self.character.name == "Trickster" then
            -- Trickster: orange triangle (SINGLE SHAPE)
            love.graphics.setColor(1,0.7,0.2,0.7)
            love.graphics.polygon('line', px, py-cs*0.22, px+cs*0.18, py+cs*0.16, px-cs*0.18, py+cs*0.16)
            love.graphics.setColor(self.color)
            love.graphics.polygon('fill', px, py-cs*0.20, px+cs*0.16, py+cs*0.14, px-cs*0.16, py+cs*0.14)
        elseif self.character.name == "Echo" or self.character.name == "The Echo" then
            -- Echo: purple circle with white outline (SINGLE SHAPE)
            love.graphics.setColor(1,1,1,0.7)
            love.graphics.circle('line', px, py, cs*0.20)
            love.graphics.setColor(self.color)
            love.graphics.circle('fill', px, py, cs*0.18)
        elseif self.character.name == "Sprinter" then
            -- Sprinter: orange ellipse (SINGLE SHAPE)
            love.graphics.setColor(1,0.5,0.2,0.7)
            love.graphics.ellipse('line', px, py, cs*0.20, cs*0.12)
            love.graphics.setColor(self.color)
            love.graphics.ellipse('fill', px, py, cs*0.18, cs*0.10)
        elseif self.character.name == "Guardian" then
            -- Guardian: blue square (SINGLE SHAPE)
            love.graphics.setColor(0.2,0.7,1,0.7)
            love.graphics.rectangle('line', px-cs*0.20, py-cs*0.20, cs*0.40, cs*0.40, 8, 8)
            love.graphics.setColor(self.color)
            love.graphics.rectangle('fill', px-cs*0.18, py-cs*0.18, cs*0.36, cs*0.36, 6, 6)
        elseif self.character.name == "Scorer" then
            -- Scorer: yellow star (SINGLE SHAPE)
            local function star(cx, cy, r, n)
                local points = {}
                for i=1, n*2 do
                    local angle = (i-1)*math.pi/n
                    local rad = (i%2==1) and r or r*0.45
                    table.insert(points, cx + math.cos(angle)*rad)
                    table.insert(points, cy + math.sin(angle)*rad)
                end
                love.graphics.setColor(1,1,1,0.8)
                love.graphics.polygon('line', points)
                love.graphics.setColor(self.color)
                love.graphics.polygon('fill', points)
            end
            star(px, py, cs*0.18, 5)
        end
        love.graphics.setLineWidth(1)
    else
        -- Fallback: simple circle (SINGLE SHAPE)
        love.graphics.setColor(1,1,1,0.7)
        love.graphics.circle('line', px, py, cs*0.20)
        love.graphics.setColor(self.color)
        love.graphics.circle('fill', px, py, cs*0.18)
    end
    love.graphics.setColor(1,1,1)

    -- Draw Architect's persisted trail if any
    if self.character and self.character.name == "Architect" and self.architectTrailPersistTimer > 0 and #self.architectLastTrailCells > 0 then
        love.graphics.setColor(self.trailColor[1], self.trailColor[2], self.trailColor[3], 0.5) -- Slightly transparent
        for _, cell_coord in ipairs(self.architectLastTrailCells) do
            if grid.cells[cell_coord.i] and grid.cells[cell_coord.i][cell_coord.j] == 'trail' then -- Ensure it's still marked as trail
                local x = grid.offsetX + (cell_coord.i-1)*grid.cellSize
                local y = grid.offsetY + (cell_coord.j-1)*grid.cellSize
                love.graphics.rectangle('fill', x, y, grid.cellSize-1, grid.cellSize-1, 6, 6)
            end
        end
        love.graphics.setColor(1,1,1) -- Reset color
    end

    -- Draw fuse shield for Guardian
    if self.fuseShieldActive then
        local px, py = grid:getNodePixelPosition(self.i, self.j)
        love.graphics.setColor(0.2, 0.8, 1, 0.5)
        love.graphics.circle('line', px, py, grid.cellSize * 0.45, 32)
        love.graphics.setColor(1,1,1)
    end

    -- Draw jammed effect on player
    if self.isJammed and (self.jamTimer or 0) > 0 then
        local px, py = grid:getNodePixelPosition(self.i, self.j)
        love.graphics.setColor(0.7, 0.3, 0.9, 0.5)
        love.graphics.circle('line', px, py, grid.cellSize * 0.5, 32)
        love.graphics.setColor(1,1,1)
    end

    -- Draw fuse visuals (color changes as fuse timer decreases)
    if self.isFuseActive and self.burningTrail and #self.burningTrail >= 2 then
        local burnProgress = 1 - (self.fuseTimer / self.fuseDuration)
        if burnProgress < 0 then burnProgress = 0 end
        if burnProgress > 1 then burnProgress = 1 end
        local fuseColor = {1, 0.3 + 0.7*burnProgress, 0.1*(1-burnProgress), 0.7}
        love.graphics.setLineWidth(5)
        love.graphics.setColor(fuseColor)
        -- Draw a glowing circle around the player as a fuse indicator
        local px, py = grid:getNodePixelPosition(self.i, self.j)
        local fuseGlow = 0.25 + 0.15*math.abs(math.sin(love.timer.getTime()*8))
        love.graphics.setColor(1, 0.5, 0.1, 0.25 + 0.25*fuseGlow)
        love.graphics.circle('fill', px, py, grid.cellSize * (0.35 + 0.18*fuseGlow))
        love.graphics.setColor(1, 0.3, 0.1, 0.7)
        love.graphics.setLineWidth(5)
        love.graphics.circle('line', px, py, grid.cellSize * 0.35, 32)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1,1,1)
    end
    -- Draw jammed icon above player
    if self.isJammed and (self.jamTimer or 0) > 0 then
        local px, py = grid:getNodePixelPosition(self.i, self.j)
        love.graphics.setColor(0.7, 0.3, 0.9, 0.9)
        love.graphics.circle('fill', px, py-grid.cellSize*0.6, grid.cellSize*0.18)
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.printf("JAM", px-grid.cellSize*0.18, py-grid.cellSize*0.65, grid.cellSize*0.36, 'center')
    end

    -- Draw floating text for powerup pickup
    if self.lastPowerupText and self.lastPowerupTextTimer and self.lastPowerupTextTimer > 0 then
        local text = self.lastPowerupText
        local font = love.graphics.newFont(14)
        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.printf(text, px - grid.cellSize, py - grid.cellSize * 1.5, grid.cellSize * 2, 'center')
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Draw fuse burn flash if active
    if self.fuseBurnFlash and self.fuseBurnFlash > 0 then
        love.graphics.setColor(1,0.2,0.1,0.5 * self.fuseBurnFlash)
        love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1,1,1)
        self.fuseBurnFlash = self.fuseBurnFlash - (love.timer.getDelta() or 0.016)
        if self.fuseBurnFlash < 0 then self.fuseBurnFlash = 0 end
    end

    -- NOTE: Removed redundant ability activation flash to prevent extra player dots
end

---
-- Returns the player's current speed, factoring in all modifiers.
function Player:getCurrentSpeed()
    local base = self.character and self.character.speed or 2.0
    local speed = base
    -- Jammed effect
    if self.isJammed then
        speed = speed * 0.6
    end
    -- Speed boost powerup
    if self.speedBoostTimer and self.speedBoostTimer > 0 then
        speed = speed * 1.5
    end
    -- Trickster decoy
    if self.tricksterDecoyActive then
        speed = speed * (self.character.decoySpeedMultiplier or 1.25)
    end
    -- Sprinter dash
    if self.sprinterDashTimer and self.sprinterDashTimer > 0 then
        speed = speed * 2.2
    end
    return speed
end

---
-- Helper function for shallow copying a table (array part).
-- @param orig The original table
function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in ipairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

---
-- Handles powerup collection and floating text feedback.
-- @param powerup The powerup object
function Player:collectPowerup(powerup)
    if powerup and not powerup.collected then
        powerup:apply(self)
        powerup.collected = true
        self.lastPowerupText = powerup.name or "Powerup!"
        self.lastPowerupTextTimer = 1.2
    end
end

function Player:move(dx, dy, grid)
    local new_i = self.i + dx
    local new_j = self.j + dy
    -- Enforce player stays only on outer border when on border
    if (new_i == 1 or new_i == grid.width or new_j == 1 or new_j == grid.height) then
        self.i = new_i
        self.j = new_j
    else
        -- If player is on inner border, push to outer
        if new_i == 2 then self.i = 1 end
        if new_i == grid.width-1 then self.i = grid.width end
        if new_j == 2 then self.j = 1 end
        if new_j == grid.height-1 then self.j = grid.height end
    end
end

function Player:activateAbility(...)
    self.abilitiesUsed = (self.abilitiesUsed or 0) + 1
    local Sound = require('src.utils.sound')
    Sound.play('ability')
    self._abilityFlashTimer = 0.35
    -- ...existing code for ability activation...
end

--[[
CHARACTER-SPECIFIC LOGIC:
- Trickster: Decoy, Swap, Stun on reverse
- Architect: Trail persistence
- Guardian: Fuse shield, defuse
- Echo: Trail pulse
- Sprinter: Dash
- Scorer: Large closure bonus
Consider refactoring these into per-character modules for maintainability.
]]

---
-- Cancels the current trail and resets player to safe state
-- @param grid The grid object
function Player:cancelTrail(grid)
    if not self.isDrawing then return end
    
    -- Clear trail from grid
    for _, trailNode in ipairs(self.trail) do
        if grid.cells[trailNode.i] and grid.cells[trailNode.i][trailNode.j] == 'trail' then
            grid.cells[trailNode.i][trailNode.j] = 'empty'
        end
    end
    
    -- Reset player state
    self.trail = {}
    self.isDrawing = false
    self.trailForDrawingLastClosure = nil
    
    -- Move player back to a safe claimed area
    local safeSpots = {}
    for i = 2, grid.width - 1 do
        for j = 2, grid.height - 1 do
            if grid:isClaimed(i, j) then
                table.insert(safeSpots, {i = i, j = j})
            end
        end
    end
    
    if #safeSpots > 0 then
        local safeSpot = safeSpots[math.random(1, #safeSpots)]
        self.i = safeSpot.i
        self.j = safeSpot.j
    else
        -- Fallback to border if no safe spots
        self.i = 1
        self.j = math.floor(grid.nodeHeight / 2)
    end
    
    do local ok, Config = pcall(require, 'src.config'); if ok and Config.debug and Config.debug.enabled then print("Trail cancelled - player moved to safe position", self.i, self.j) end end
end

return Player