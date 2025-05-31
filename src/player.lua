local Player = {}
local Gamestate = require 'hump.gamestate' -- For accessing game state

function Player:load(grid, character)
    self.i = math.floor(grid.width/2)
    self.j = math.floor(grid.height/2)
    self.character = character or require('src.characters.architect')
    self.moveDelay = 0.15 / (self.character.speed or 2.0) 
    self.moveTimer = 0
    self.dir = {x=0, y=0}
    self.trail = {}
    self.isDrawing = false
    self.color = self.character.color or {0.2, 0.6, 1}
    self.trailColor = self.character.trailColor or {1, 0.8, 0.2}
    
    -- Character-specific initializations
    if self.character.name == "Trickster" then
        self.tricksterSwapTimer = 10 -- seconds
    end
    if self.character.name == "Architect" then
        self.architectTrailPersistTimer = 0
        self.architectLastTrailCells = {} -- To store the trail if player stops drawing
    end
end

local function isClaimed(grid, i, j)
    return grid.cells[i] and (grid.cells[i][j] == 'claimed')
end

local function isTrail(grid, i, j)
    return grid.cells[i] and (grid.cells[i][j] == 'trail')
end

function Player:update(dt, grid)
    local game = Gamestate.current() -- Access Game state for enemies, currentRealm etc.

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

    self.moveTimer = self.moveTimer - dt
    if self.moveTimer <= 0 then
        local dx, dy = 0, 0
        local moved = false
        if love.keyboard.isDown('up') then dy = -1; moved = true end
        if love.keyboard.isDown('down') then dy = 1; moved = true end
        if love.keyboard.isDown('left') then dx = -1; moved = true end
        if love.keyboard.isDown('right') then dx = 1; moved = true end

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
            if self.character and self.character.name == "Architect" and self.architectTrailPersistTimer > 0 and #self.architectLastTrailCells > 0 then
                 -- Architect started moving again, if they are not drawing a *new* trail from a claimed zone,
                 -- they might be intending to connect to the persistent one.
                 -- For now, moving will cancel the *specific* persistence timer if they start a new line from claimed territory.
                 -- If they move into an empty cell to extend, it should ideally connect to self.architectLastTrailCells.
                 -- This part needs careful logic for reconnecting to a persisted trail.
                 -- For a simpler first pass, if they start a *new* trail segment, the old persisted one continues its own timer.
            end

            local ni, nj = self.i + dx, self.j + dy
            if grid:isInside(ni, nj) then
                local prevClaimedPercent = grid:getClaimedPercent()
                local prevCellWasClaimed = isClaimed(grid, self.i, self.j)
                local nextCellIsClaimed = isClaimed(grid, ni, nj)
                local nextCellIsTrail = isTrail(grid, ni, nj)

                if not self.isDrawing and nextCellIsClaimed then
                    self.i, self.j = ni, nj
                    self.moveTimer = self.moveDelay
                    return
                end

                if self.isDrawing and nextCellIsTrail then
                     -- Check if it's part of Architect's own persisted trail
                    if self.character and self.character.name == "Architect" and self.architectTrailPersistTimer > 0 then
                        local isOwnPersistedTrail = false
                        for _, pcell in ipairs(self.architectLastTrailCells) do
                            if pcell.i == ni and pcell.j == nj then
                                isOwnPersistedTrail = true; break
                            end
                        end
                        if isOwnPersistedTrail then 
                            -- Allow crossing to close if it's the persisted trail, effectively merging
                            -- The current self.trail should be merged with self.architectLastTrailCells
                            -- Then proceed to closure logic. This is complex. 
                            -- For now, let's assume standard closure if it hits any trail cell.
                        else return -- Collided with a different part of current trail or other trail
                        end
                    else
                        return -- Collided with own trail (non-Architect or non-persisted)
                    end
                end
                
                self.i, self.j = ni, nj
                self.moveTimer = self.moveDelay
                self.architectTrailPersistTimer = 0 -- Actively moving/drawing new segment, stop specific persistence of previous segment
                if #self.architectLastTrailCells > 0 and not nextCellIsClaimed then
                    -- If architect had a persisted trail and is now drawing into empty space,
                    -- assume they are extending/creating a new trail. The old one might still be there if its timer hasn't run out.
                    -- To simplify, let's clear architectLastTrailCells if they start drawing a new segment from scratch.
                    -- self.architectLastTrailCells = {}
                end

                if prevCellWasClaimed and not nextCellIsClaimed and not self.isDrawing then 
                    self.isDrawing = true
                    self.trail = {{i=self.i, j=self.j}} -- Start trail from new position
                    grid.cells[self.i][self.j] = 'trail'
                    self.architectLastTrailCells = {} -- Starting a new trail, clear any persisted one
                elseif self.isDrawing and not nextCellIsClaimed then 
                    table.insert(self.trail, {i=self.i, j=self.j})
                    grid.cells[self.i][self.j] = 'trail'
                elseif self.isDrawing and nextCellIsClaimed then 
                    self.isDrawing = false
                    local closedTrail = shallowcopy(self.trail)
                    print("Player:update - About to call grid:closeArea. Type of closedTrail: " .. type(closedTrail))
                    if type(closedTrail) == "table" then
                        print("Player:update - Length of closedTrail: " .. #closedTrail)
                        for i, cell in ipairs(closedTrail) do
                            print("Player:update - closedTrail cell " .. i .. ": i=" .. cell.i .. ", j=" .. cell.j)
                        end
                    end
                                        
                    local newlyClaimedCellCount -- Declare here
                    if #closedTrail > 0 then 
                        for _, cell_coord in ipairs(closedTrail) do
                            if grid.cells[cell_coord.i] and grid.cells[cell_coord.i][cell_coord.j] == 'trail' then
                                grid.cells[cell_coord.i][cell_coord.j] = 'pending_claim'
                            end
                        end
                        
                        newlyClaimedCellCount = grid:closeArea(closedTrail) -- Assign here
                        print("Player:update - Returned from grid:closeArea. Type of newlyClaimedCellCount: " .. type(newlyClaimedCellCount) .. ", Value: " .. tostring(newlyClaimedCellCount))
                        
                        for _, cell_coord in ipairs(closedTrail) do
                             if grid.cells[cell_coord.i] and grid.cells[cell_coord.i][cell_coord.j] == 'pending_claim' then
                                grid.cells[cell_coord.i][cell_coord.j] = 'claimed'
                             end
                        end
                    else
                        newlyClaimedCellCount = 0
                        print("Player:update - closedTrail was empty, newlyClaimedCellCount set to 0")
                    end
                    self.trail = {}
                    self.architectLastTrailCells = {} -- Trail closed, clear persisted one
                    self.architectTrailPersistTimer = 0

                    local afterClaimedPercent = grid:getClaimedPercent()
                    if afterClaimedPercent > prevClaimedPercent or newlyClaimedCellCount > 0 then
                        if game and game.currentRealm and game.currentRealm.onZoneClosed then
                            game.currentRealm:onZoneClosed(grid)
                        end
                        
                        if self.character and self.character.name == "Architect" then
                            -- Architect: Loop Closure Bonus
                            if self.character.loopClosureBonusPercent and newlyClaimedCellCount > 0 then
                                -- Calculate bonus cells based on the *newly claimed area*, not total grid area
                                local bonusCellsCount = math.floor(newlyClaimedCellCount * self.character.loopClosureBonusPercent)
                                if bonusCellsCount > 0 then
                                    -- The addBonusClaimedCells function needs to be smarter or we simplify the concept.
                                    -- For now, let's assume it adds a flat number of cells, or we can award score directly.
                                    -- Let's award score for now, as adding specific cells is complex without more grid logic.
                                    local loopBonusScore = bonusCellsCount * 10 -- Example: 10 points per bonus cell equivalent
                                    if game and game.addScore then
                                        game:addScore(loopBonusScore)
                                    end
                                    print("Architect Loop Closure Bonus: Score +" .. loopBonusScore .. " (equiv. " .. bonusCellsCount .. " cells)")
                                end
                            end

                            -- Architect: Large Zone Bonus (Score)
                            if self.character.largeZoneBonusMultiplier and newlyClaimedCellCount >= self.character.largeZoneThreshold then
                                local baseScoreForClosure = newlyClaimedCellCount * 10 -- Example: 10 points per cell claimed
                                local largeZoneBonusScore = baseScoreForClosure * (self.character.largeZoneBonusMultiplier - 1) -- Calculate only the bonus part
                                if game and game.addScore then
                                    game:addScore(largeZoneBonusScore) -- Add the bonus amount
                                    -- The base score for closure should be handled separately if not already.
                                    -- For simplicity, let's assume newlyClaimedCellCount itself contributes to a base score elsewhere or here.
                                    -- Let's add the base score here as well for now.
                                    game:addScore(baseScoreForClosure)
                                end
                                print("Architect Large Zone Bonus Applied! Total from this closure: " .. (baseScoreForClosure + largeZoneBonusScore) .. " (Base: " .. baseScoreForClosure .. ", Bonus: " .. largeZoneBonusScore .. ")")
                            elseif newlyClaimedCellCount > 0 then -- Grant base score for any closure
                                local baseScoreForClosure = newlyClaimedCellCount * 10 -- Example: 10 points per cell claimed
                                if game and game.addScore then
                                    game:addScore(baseScoreForClosure)
                                end
                                print("Closure score: " .. baseScoreForClosure)
                            end

                            -- Architect: Freeze Enemies
                            if game and game.enemies and self.character.freezeDuration then 
                                for _, enemy in ipairs(game.enemies) do
                                    if enemy.setFrozen then 
                                        enemy:setFrozen(self.character.freezeDuration)
                                    end
                                end
                                print("Architect Passive: Enemies Frozen for " .. self.character.freezeDuration .. "s")
                            end
                        end
                    end
                end
            end
        end
    end
end

function Player:draw(grid)
    -- Draw trail
    if not grid._jammedTrail and self.isDrawing and #self.trail > 0 then
        love.graphics.setColor(self.trailColor)
        for _, cell in ipairs(self.trail) do
            local x = grid.offsetX + (cell.i-1)*grid.cellSize
            local y = grid.offsetY + (cell.j-1)*grid.cellSize
            love.graphics.rectangle('fill', x, y, grid.cellSize-1, grid.cellSize-1, 6, 6)
        end
    end
    -- Draw player
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    love.graphics.setColor(self.color)
    love.graphics.circle('fill', x, y, grid.cellSize*0.35)
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
end

-- Helper function for shallow copying a table (array part)
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

return Player
