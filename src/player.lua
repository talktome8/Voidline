-- src/player.lua
-- Handles player input, movement, trail creation, hitbox logic, and all speed modifiers via getCurrentSpeed()

local love = require "love" -- Added missing love require
local Player = {}
local Gamestate = require 'hump.gamestate' -- For accessing game state

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
    print('DEBUG: Player:load called with character:', character and character.name or 'NIL', tostring(character))
    if character then
        for k,v in pairs(character) do print('DEBUG: Player:load character['..tostring(k)..']='..tostring(v)) end
    end
    -- Player position is now node-based. Nodes are 1 to grid.nodeWidth and 1 to grid.nodeHeight
    self.i = 1 -- Start on the first column of nodes (left border)
    self.j = math.floor(grid.nodeHeight / 2) -- Start at a middle node vertically

    -- Always use the selectedCharacter from Game if not explicitly passed
    if not character then
        if _G.selectedCharacter then
            character = getCharacterByName(_G.selectedCharacter.name)
            print('DEBUG: Player:load fallback to _G.selectedCharacter:', character.name, tostring(character))
        else
            character = getCharacterByName("Architect")
            print('DEBUG: Player:load fallback to Architect (default)', tostring(character))
        end
    else
        character = getCharacterByName(character.name)
        print('DEBUG: Player:load normalized to canonical object:', character.name, tostring(character))
    end
    self.character = character
    print('DEBUG: Player.character set to:', self.character and self.character.name or 'NIL', tostring(self.character))
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
                print("Trickster decoy expired")
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
                local game = require('src.game')
                if game and game.gameOver ~= nil then
                    game.gameOver = true
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
        -- Guardian: Defuse fuse once per run (D)
        if self.character.name == "Guardian" then
            if not self.fuseDefused and love.keyboard.isDown('d') and self.isFuseActive then
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
        -- Determine input direction
        local input_dx, input_dy = 0, 0
        if love.keyboard.isDown('left') then input_dx = -1 end
        if love.keyboard.isDown('right') then input_dx = 1 end -- Changed elseif to if
        if love.keyboard.isDown('up') then input_dy = -1 end
        if love.keyboard.isDown('down') then input_dy = 1 end -- Changed elseif to if

        local dx_node, dy_node = 0, 0
        local moved = false

        -- Allow diagonal movement
        if input_dx ~= 0 or input_dy ~= 0 then
            dx_node = input_dx
            dy_node = input_dy
            moved = true
        end
        -- Now, moved is true if there was any input.
        -- dx_node and dy_node can both be non-zero for diagonal movement.

        -- Trickster Decoy Activation
        if self.character and self.character.name == "Trickster" and love.keyboard.isDown('space') then
            if not self.tricksterDecoyActive and self.tricksterDecoyCooldownTimer <= 0 then
                self.tricksterDecoyActive = true
                self.tricksterDecoyTimer = self.character.decoyDuration
                self.tricksterDecoyCooldownTimer = self.character.decoyCooldown
                self.tricksterDecoyPosition = {i = self.i, j = self.j}
                -- self.character.speed = self.originalSpeed * self.character.decoySpeedMultiplier -- Apply speed boost
                self.moveDelay = 0.15 / self.character.speed -- Recalculate moveDelay with new speed
                print("Trickster decoy activated!")
            end
        end

        if self.character and self.character.name == "Architect" and not moved and self.isDrawing and #self.trail > 0 then
            -- Architect stopped moving while drawing, activate trail persistence
            if self.architectTrailPersistTimer <= 0 then -- Only activate if not already persisting
                self.architectTrailPersistTimer = self.character.trailPersistDuration
                self.architectLastTrailCells = shallowcopy(self.trail) -- Store current trail for persistence
                -- print("Architect trail persistence activated")
            end
            -- Player does not move, but trail persists for a bit
            -- We don't return here, to allow other logic like drawing to proceed if needed.
        end

        if moved then
            local prev_node_i, prev_node_j = self.i, self.j
            local next_node_i, next_node_j = self.i + dx_node, self.j + dy_node

            -- DEBUG: Check grid object and its methods
            print("Player:update - grid type:", type(grid))
            if type(grid) == "table" then
                print("Player:update - grid.isNodeValid type:", type(grid.isNodeValid))
                print("Player:update - grid.isLineSafe type:", type(grid.isLineSafe))
            end

            if grid:isNodeValid(next_node_i, next_node_j) then
                local lineIsSafe = grid:isLineSafe(prev_node_i, prev_node_j, next_node_i, next_node_j)

                if not self.isDrawing and not lineIsSafe then
                    -- Start drawing a new trail
                    self.isDrawing = true
                    self.trail = { {i=prev_node_i, j=prev_node_j}, {i=next_node_i, j=next_node_j} }
                    -- No direct grid cell marking for trail yet with node system
                    print("Player started drawing trail from node ("..prev_node_i..","..prev_node_j..") to ("..next_node_i..","..next_node_j..")")
                elseif self.isDrawing and not lineIsSafe then
                    -- Continue drawing
                    table.insert(self.trail, {i=next_node_i, j=next_node_j})
                    -- No direct grid cell marking
                    print("Player continued trail to node ("..next_node_i..","..next_node_j..")")
                elseif self.isDrawing and lineIsSafe then
                    -- Reached a safe line, attempt to close area
                    self.isDrawing = false
                    self.attemptingClosure = true -- MODIFIED: Set flag for drawing this frame

                    -- Make sure the last point is added to trail
                    if #self.trail == 0 or not (self.trail[#self.trail].i == next_node_i and self.trail[#self.trail].j == next_node_j) then
                        table.insert(self.trail, {i=next_node_i, j=next_node_j})
                    end
                    print("Player attempting to close trail at node ("..next_node_i..","..next_node_j.."). Trail length: " .. #self.trail)

                    -- Save full trail for closure and drawing
                    self.trailForDrawingLastClosure = shallowcopy(self.trail)

                    if #self.trail >= 3 then -- Ensure trail is long enough to form an area
                        local newlyClaimedCellCount = grid:closeAreaByNodes(self.trail, self)
                        print("Grid:closeAreaByNodes claimed " .. newlyClaimedCellCount .. " cells.")
                        -- TODO: Add scoring or other logic based on newlyClaimedCellCount
                    else
                        print("Trail too short to close, clearing trail.")
                    end
                    -- When trail is cleared (zone closed or stopped drawing), add to fadingTrails
                    if not self.isDrawing and #self.trail > 1 then
                        table.insert(self.fadingTrails, {trail=shallowcopy(self.trail), timer=0.7})
                        self.trail = {}
                    end
                elseif not self.isDrawing and lineIsSafe then
                    -- Moving along a safe line, not drawing
                    self.trail = {} -- Ensure trail is clear
                end

                self.i, self.j = next_node_i, next_node_j
                self.moveTimer = self.moveDelay
                
                -- ... (Architect trail persistence logic might need adjustment here too) ...
            end
        end
    end

    -- Update fading trails
    for i = #self.fadingTrails, 1, -1 do
        local t = self.fadingTrails[i]
        t.timer = t.timer - dt
        if t.timer <= 0 then table.remove(self.fadingTrails, i) end
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
    if self.trailForDrawingLastClosure then self.trailForDrawingLastClosure = nil end

    -- Draw Trickster's Decoy (משולש)
    if self.character and self.character.name == "Trickster" and self.tricksterDecoyActive and self.tricksterDecoyPosition then
        local decoyColor = {self.color[1], self.color[2], self.color[3], 0.5}
        love.graphics.setColor(decoyColor)
        local x = grid.offsetX + (self.tricksterDecoyPosition.i-0.5)*grid.cellSize
        local y = grid.offsetY + (self.tricksterDecoyPosition.j-0.5)*grid.cellSize
        love.graphics.polygon('fill', x, y-18, x+16, y+14, x-16, y+14)
    end

    -- Draw player (unique shape per character, תמיד!)
    local px, py = grid:getNodePixelPosition(self.i, self.j)
    love.graphics.setColor(self.color)
    local cs = grid.cellSize
    if self.character and self.character.name then
        -- DEBUG: Drawing character
        -- Outline
        love.graphics.setLineWidth(3)
        if self.character.name == "Architect" then
            -- Architect: blue rounded square with white border
            love.graphics.setColor(1,1,1,0.9)
            love.graphics.rectangle('line', px-cs*0.22, py-cs*0.22, cs*0.44, cs*0.44, 10, 10)
            love.graphics.setColor(0.1,0.5,1,0.7)
            love.graphics.rectangle('line', px-cs*0.20, py-cs*0.20, cs*0.40, cs*0.40, 8, 8)
            love.graphics.setColor(self.color)
            love.graphics.rectangle('fill', px-cs*0.18, py-cs*0.18, cs*0.36, cs*0.36, 6, 6)
        elseif self.character.name == "Trickster" then
            -- Trickster: orange triangle with glow
            love.graphics.setColor(1,0.7,0.2,0.7)
            love.graphics.polygon('line', px, py-cs*0.24, px+cs*0.20, py+cs*0.18, px-cs*0.20, py+cs*0.18)
            love.graphics.setColor(1,0.5,0.1,0.25)
            love.graphics.circle('fill', px, py, cs*0.23)
            love.graphics.setColor(self.color)
            love.graphics.polygon('fill', px, py-cs*0.22, px+cs*0.18, py+cs*0.16, px-cs*0.18, py+cs*0.16)
        elseif self.character.name == "Echo" or self.character.name == "The Echo" then
            -- Echo: purple circle with white highlight
            love.graphics.setColor(1,1,1,0.7)
            love.graphics.circle('line', px, py, cs*0.22)
            love.graphics.setColor(0.7,0.5,1,0.7)
            love.graphics.circle('line', px, py, cs*0.20)
            love.graphics.setColor(self.color)
            love.graphics.circle('fill', px, py, cs*0.18)
        elseif self.character.name == "Sprinter" then
            -- Sprinter: orange ellipse with speed lines
            love.graphics.setColor(1,0.5,0.2,0.7)
            love.graphics.ellipse('line', px, py, cs*0.22, cs*0.14)
            love.graphics.setColor(self.color)
            love.graphics.ellipse('fill', px, py, cs*0.20, cs*0.12)
            love.graphics.setColor(1,0.7,0.2,0.5)
            love.graphics.line(px-cs*0.28, py, px-cs*0.12, py)
            love.graphics.line(px+cs*0.12, py, px+cs*0.28, py)
        elseif self.character.name == "Guardian" then
            -- Guardian: blue double square with shield glow
            love.graphics.setColor(0.2,0.7,1,0.7)
            love.graphics.rectangle('line', px-cs*0.22, py-cs*0.22, cs*0.44, cs*0.44, 10, 10)
            love.graphics.setColor(self.color)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle('line', px-cs*0.18, py-cs*0.18, cs*0.36, cs*0.36, 6, 6)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle('fill', px-cs*0.13, py-cs*0.13, cs*0.26, cs*0.26, 6, 6)
            love.graphics.setColor(0.2,0.7,1,0.18)
            love.graphics.circle('fill', px, py, cs*0.30)
        elseif self.character.name == "Scorer" then
            -- Scorer: yellow star with white outline
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
                love.graphics.setColor(1,1,0.3,0.7)
                love.graphics.polygon('line', points)
                love.graphics.setColor(self.color)
                love.graphics.polygon('fill', points)
            end
            star(px, py, cs*0.19, 5)
        end
        love.graphics.setLineWidth(1)
    else
        love.graphics.setColor(0.8,0.8,0.8,0.7)
        love.graphics.circle('line', px, py, cs*0.27)
        love.graphics.setColor(self.color)
        love.graphics.circle('fill', px, py, cs*0.25)
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

    -- Draw ability activation flash (newly added)
    if self._abilityFlashTimer and self._abilityFlashTimer > 0 then
        local alpha = math.min(1, self._abilityFlashTimer / 0.35)
        love.graphics.setColor(1, 1, 0.3, 0.45 * alpha)
        love.graphics.circle('fill', px, py, cs*0.38 + 12*alpha, 32)
        love.graphics.setColor(1,1,1,1)
    end
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

return Player
