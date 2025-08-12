local love = require "love"

-- Safe Config loading with fallback
local Config = nil
local cellColors = nil

local success, config = pcall(require, 'src.config')
if success then
    Config = config
    if Config and Config.display and Config.display.colors then
        cellColors = Config.display.colors
    if Config.debug and Config.debug.enabled then print("Grid: Successfully loaded Config colors") end
    else
    if Config.debug and Config.debug.enabled then print("Grid: Config loaded but missing display.colors") end
    end
else
    print("Grid: Failed to load Config - " .. tostring(config))
end

-- Fallback colors if Config fails
if not cellColors then
    if Config and Config.debug and Config.debug.enabled then print("Grid: Using fallback colors") end
    cellColors = {
        empty = {0.1, 0.1, 0.15, 1.0},
        claimed = {0.2, 0.6, 1.0, 0.8},
        target_completed = {0.2, 1.0, 0.2, 0.9}, -- Bright green for completed target shapes
        trail = {0.3, 0.8, 1.0, 0.9},
        player = {1.0, 1.0, 1.0, 1.0},
        enemy = {0.9, 0.2, 0.2, 1.0},
        border = {0.4, 0.4, 0.6, 1.0},
        highlight = {1.0, 1.0, 0.3, 0.8},
        island = {0.6, 0.3, 0.9, 0.7}
    }
end

local Grid = {}

-- Use configuration-driven dimensions and cell size with fallbacks
if Config and Config.grid then
    Grid.width = Config.grid.width
    Grid.height = Config.grid.height
    Grid.cellSize = Config.grid.cellSize or 16 -- Larger cells for better visual impact
else
    if Config and Config.debug and Config.debug.enabled then print("Grid: Using fallback grid settings") end
    Grid.width = 60
    Grid.height = 45
    Grid.cellSize = 16 -- Larger cells for better visual impact
end
Grid.cells = {}

-- Local bounds helper for ultra-safe index checks
local function inBounds(self, x, y)
    return x ~= nil and y ~= nil and x >= 1 and x <= self.width and y >= 1 and y <= self.height
end
Grid.nodeWidth = 0 -- Will be self.width + 1
Grid.nodeHeight = 0 -- Will be self.height + 1

-- Animation system for visual feedback
Grid.animations = {}
Grid.animationTime = 0
Grid.particleSystem = nil

---
-- Checks if a cell is inside the grid boundaries.
-- @param i The cell's i index
-- @param j The cell's j index
function Grid:isInside(i, j)
    return i >= 1 and i <= self.width and j >= 1 and j <= self.height
end

---
-- Checks if a cell is claimed.
-- @param i The cell's i index
-- @param j The cell's j index
function Grid:isClaimed(i, j)
    return self.cells[i] and (self.cells[i][j] == 'claimed' or self.cells[i][j] == 'island')
end

---
-- Initializes the grid and sets up all cells.
function Grid:load()
    for i = 1, self.width do
        self.cells[i] = {}
        for j = 1, self.height do
            if i == 1 or i == self.width or j == 1 or j == self.height then
                self.cells[i][j] = 'claimed' -- Borders are always "claimed"
            elseif (i == math.floor(self.width/2) and j == math.floor(self.height/2)) then
                self.cells[i][j] = 'island' -- דוגמה: אי במרכז (אפשר לשפר בהמשך)
            else
                self.cells[i][j] = 'empty'
            end
        end
    end
    self.nodeWidth = self.width + 1
    self.nodeHeight = self.height + 1

    -- Initialize feedback buffers (nil-safe defaults)
    self._recentlyClaimedCells = self._recentlyClaimedCells or {}
    self._recentlyClaimedTimer = self._recentlyClaimedTimer or 0
    self._recentlyClaimedDuration = self._recentlyClaimedDuration or 0.4
end

---
-- Updates grid state (timers, effects, etc).
-- @param dt Delta time
function Grid:update(dt)
    -- Echo Lab support: after zone closure, briefly revert claimed cells to empty, then re-claim
    if self._echoLabTimer and self._echoLabTimer > 0 then
        self._echoLabTimer = self._echoLabTimer - dt
        if self._echoLabTimer <= 0 and self._echoLabToClaim then
            for _, cell in ipairs(self._echoLabToClaim) do
                self.cells[cell.i][cell.j] = 'claimed'
            end
            self._echoLabToClaim = nil
        end
    end

    -- אפקט jammedTrail: אם הופעל, לא מציגים את ה-trail
    if self._jammedTrail and self._jammedTrail > 0 then
        self._jammedTrail = self._jammedTrail - dt
        if self._jammedTrail < 0 then self._jammedTrail = nil end
    end
    -- Recently claimed highlight effect
    if self._recentlyClaimedTimer and self._recentlyClaimedTimer > 0 then
        self._recentlyClaimedTimer = self._recentlyClaimedTimer - dt
        if self._recentlyClaimedTimer <= 0 then
            self._recentlyClaimedCells = nil
            self._recentlyClaimedTimer = 0
        end
    end
    
    -- Update success highlight timer
    if self._successHighlightTimer and self._successHighlightTimer > 0 then
        self._successHighlightTimer = self._successHighlightTimer - dt
        if self._successHighlightTimer <= 0 then
            self._successHighlightCells = nil
        end
    end
end

---
-- Draws the grid, including cells, infected zones, and debug overlays.
function Grid:draw()
    -- Protection: If the grid is not initialized, do not draw
    if not self.cells or not self.cells[1] then return end
    
    -- Initialize offset values if they don't exist
    if not self.offsetX or not self.offsetY then
    if Config and Config.debug and Config.debug.enabled then print("Grid: Initializing missing offset values") end
        local screenWidth, screenHeight = love.graphics.getDimensions()
        local gridPixelWidth = self.width * self.cellSize
        local gridPixelHeight = self.height * self.cellSize
        -- Center the grid properly for 1450x850 with HUD space
        self.offsetX = 340  -- Adjusted for larger window and cells
        self.offsetY = math.floor((screenHeight - gridPixelHeight) / 2)
    if Config and Config.debug and Config.debug.enabled then print("Grid: Set offsetX =", self.offsetX, "offsetY =", self.offsetY) end
    end
    
    -- Draw Cells (exclude trail cells to prevent double rendering)
    for i = 1, self.width do
        for j = 1, self.height do
            local cellType = self.cells[i] and self.cells[i][j] or 'empty'
            
            -- Skip drawing trail cells - Player system handles trail visualization
            if cellType == 'trail' then
                goto continue
            end
            
            local color = cellColors[cellType] or cellColors.claimed
            if cellType == 'claimed' then
                color = cellColors.claimed
            end
            local x = self.offsetX + (i-1)*self.cellSize
            local y = self.offsetY + (j-1)*self.cellSize
            local highlight = false
            if self._recentlyClaimedCells then
                for _, cell in ipairs(self._recentlyClaimedCells) do
                    if cell.i == i and cell.j == j then
                        highlight = true
                        break
                    end
                end
            end
            if highlight then
                local t = math.max(0, self._recentlyClaimedTimer or 0) / (self._recentlyClaimedDuration or 1)
                love.graphics.setColor(color[1]+0.5*t, color[2]+0.5*t, color[3]+0.5*t, 1)
            else
                love.graphics.setColor(color)
            end
            -- Draw cell border for better visual clarity
            love.graphics.rectangle('fill', x, y, self.cellSize-1, self.cellSize-1, 6, 6)
            love.graphics.setColor(0.08,0.12,0.18,0.18)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle('line', x, y, self.cellSize-1, self.cellSize-1, 6, 6)
            
            ::continue::
        end
    end
    -- Draw infected cells
    for i=1,self.width do
        for j=1,self.height do
            if self.cells[i] and self.cells[i][j] == 'infected' then
                local x = self.offsetX + (i-1)*self.cellSize
                local y = self.offsetY + (j-1)*self.cellSize
                love.graphics.setColor(1,0.3,0.3,0.7)
                love.graphics.rectangle('fill', x, y, self.cellSize, self.cellSize)
            end
        end
    end
    love.graphics.setColor(1,1,1)

    -- ✅ ENHANCED SAFE BORDER VISUALIZATION
    -- Draw thick, glowing border frame to indicate safe zone
    local borderThickness = 4
    local glowColor = {0.4, 0.8, 1.0, 0.8}  -- Cyan glow
    local frameX = self.offsetX - borderThickness
    local frameY = self.offsetY - borderThickness
    local frameWidth = self.width * self.cellSize + borderThickness * 2
    local frameHeight = self.height * self.cellSize + borderThickness * 2
    
    -- Draw glow effect
    love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * 0.3)
    love.graphics.setLineWidth(borderThickness + 2)
    love.graphics.rectangle('line', frameX - 1, frameY - 1, frameWidth + 2, frameHeight + 2)
    
    -- Draw main border
    love.graphics.setColor(glowColor)
    love.graphics.setLineWidth(borderThickness)
    love.graphics.rectangle('line', frameX, frameY, frameWidth, frameHeight)
    
    -- Reset graphics state
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1,1,1)

    -- Flash effect for recently claimed cells
    if self._recentlyClaimedCells and self._recentlyClaimedTimer and self._recentlyClaimedTimer > 0 then
        local flashAlpha = math.min(1, self._recentlyClaimedTimer / (self._recentlyClaimedDuration or 0.4))
        love.graphics.setColor(1, 1, 0.3, 0.45 * flashAlpha)
        for _, cell in ipairs(self._recentlyClaimedCells) do
            love.graphics.rectangle('fill', self.offsetX + (cell.i-1)*self.cellSize, self.offsetY + (cell.j-1)*self.cellSize, self.cellSize-1, self.cellSize-1, 4, 4)
        end
        love.graphics.setColor(1,1,1,1)
    end
    
    -- SUCCESS HIGHLIGHT: Flash success areas in cyan
    if self._successHighlightTimer and self._successHighlightTimer > 0 and self._successHighlightCells then
        local flashAlpha = math.min(1, self._successHighlightTimer / 2.0)
        love.graphics.setColor(0.2, 1.0, 1.0, 0.4 * flashAlpha)
        for _, cell in ipairs(self._successHighlightCells) do
            love.graphics.rectangle('fill', self.offsetX + (cell.i-1)*self.cellSize, self.offsetY + (cell.j-1)*self.cellSize, self.cellSize-1, self.cellSize-1, 4, 4)
        end
        love.graphics.setColor(1,1,1,1)
    end

    -- Optional: Draw nodes for debugging
    -- love.graphics.setColor(0.5, 0.5, 0.5, 0.5) -- Light gray for nodes
    -- for ni = 1, self.nodeWidth do
    --     for nj = 1, self.nodeHeight do
    --         local px, py = self:getNodePixelPosition(ni, nj)
    --         love.graphics.circle('fill', px, py, 2)
    --     end
    -- end
    -- love.graphics.setColor(1,1,1)
end

---
-- Converts node coordinates to pixel coordinates.
-- @param node_i Node i index
-- @param node_j Node j index
function Grid:getNodePixelPosition(node_i, node_j)
    if not self.offsetX or not self.offsetY or not self.cellSize then
        print("Error: Grid offset or cellSize not initialized before getNodePixelPosition call.")
        return 0, 0 -- Return a default or handle error appropriately
    end
    -- Nodes are at the corners of cells. Node (1,1) is top-left of cell (1,1).
    -- Pixel position is offsetX + (node_index - 1) * cellSize
    local px = self.offsetX + (node_i - 1) * self.cellSize
    local py = self.offsetY + (node_j - 1) * self.cellSize
    return px, py
end

---
-- Attempts to close an area based on a trail using advanced polygon filling.
-- @param trail List of node coordinates from player movement
function Grid:closeArea(trail)
    if Config and Config.debug and Config.debug.enabled then print("Grid:closeArea called. Using advanced polygon-based area closure.") end
    local newlyClaimedCellCount = 0

    if not trail or #trail < 3 then 
    if Config and Config.debug and Config.debug.enabled then print("Trail too short for closure:", trail and #trail or 0, "points") end
        return 0
    end

    -- ✅ ENHANCED CLOSURE: Check if trail connects to any claimed area (not just border)
    local connectsToClaimed = false
    local connectsToBorder = false
    
    for _, node in ipairs(trail) do
        local cellI = math.max(1, math.min(self.width, math.floor(node.i + 0.5)))
        local cellJ = math.max(1, math.min(self.height, math.floor(node.j + 0.5)))
        
        -- Check if on border
        if cellI == 1 or cellI == self.width or cellJ == 1 or cellJ == self.height then
            connectsToBorder = true
        end
        
        -- Check if adjacent to claimed territory
        local dirs = {{0,0}, {1,0}, {-1,0}, {0,1}, {0,-1}, {1,1}, {-1,-1}, {1,-1}, {-1,1}}
        for _, dir in ipairs(dirs) do
            local checkI, checkJ = cellI + dir[1], cellJ + dir[2]
            if self:isInside(checkI, checkJ) and self:isClaimed(checkI, checkJ) then
                connectsToClaimed = true
                break
            end
        end
        
        if connectsToClaimed and connectsToBorder then break end
    end
    
    local canClose = connectsToBorder or connectsToClaimed
    if not canClose then
    if Config and Config.debug and Config.debug.enabled then print("CLOSURE BLOCKED: Trail must connect to border or claimed territory") end
        return 0
    end

    -- Remove duplicate consecutive points and ensure closed polygon
    local cleanTrail = {}
    local lastPoint = nil
    for _, node in ipairs(trail) do
        local cellI = math.max(1, math.min(self.width, math.floor(node.i + 0.5)))
        local cellJ = math.max(1, math.min(self.height, math.floor(node.j + 0.5)))
        local currentPoint = {i = cellI, j = cellJ}
        
        if not lastPoint or (currentPoint.i ~= lastPoint.i or currentPoint.j ~= lastPoint.j) then
            table.insert(cleanTrail, currentPoint)
            lastPoint = currentPoint
        end
    end
    
    -- Ensure polygon is closed by adding first point to end if needed
    if #cleanTrail > 2 then
        local first = cleanTrail[1]
        local last = cleanTrail[#cleanTrail]
        if first.i ~= last.i or first.j ~= last.j then
            table.insert(cleanTrail, {i = first.i, j = first.j})
        end
    end
    
    if #cleanTrail < 4 then -- Need at least 4 points including closure
        print("Clean trail too short for closure:", #cleanTrail, "points")
        return 0
    end
    
    if Config and Config.debug and Config.debug.enabled then print("Clean trail has", #cleanTrail, "points for polygon closure") end
    
    -- Find bounding box for efficiency
    local minI, maxI = math.huge, -math.huge
    local minJ, maxJ = math.huge, -math.huge
    
    for _, cell in ipairs(cleanTrail) do
        minI = math.min(minI, cell.i)
        maxI = math.max(maxI, cell.i)
        minJ = math.min(minJ, cell.j)
        maxJ = math.max(maxJ, cell.j)
    end
    
    -- REVOLUTIONARY Multi-Method Point-in-Polygon Detection
    local function isPointInPolygon(x, y, polygon)
        if not polygon or #polygon < 3 then return false end
        
        -- Method 1: Enhanced Ray Casting with better edge handling
        local inside_ray = false
        local j = #polygon - 1  -- Don't include the closing duplicate point
        
        for i = 1, #polygon - 1 do
            local xi, yi = polygon[i].i, polygon[i].j
            local xj, yj = polygon[j].i, polygon[j].j
            
            -- Handle horizontal edges more carefully
            if math.abs(yi - yj) < 0.001 then  -- Horizontal edge
                if math.abs(y - yi) < 0.001 and x >= math.min(xi, xj) - 0.5 and x <= math.max(xi, xj) + 0.5 then
                    return true  -- Point is on or very near horizontal edge
                end
            else
                -- Enhanced ray casting with better precision
                if ((yi > y) ~= (yj > y)) then
                    local intersectX = (xj - xi) * (y - yi) / (yj - yi) + xi
                    if x < intersectX then
                        inside_ray = not inside_ray
                    elseif math.abs(x - intersectX) < 0.5 then
                        return true  -- Point is very close to edge
                    end
                end
            end
            j = i
        end
        
        -- Method 2: Proximity Detection - if close to any trail point, consider inside
        local min_distance = math.huge
        for i = 1, #polygon - 1 do
            local px, py = polygon[i].i, polygon[i].j
            local dist = math.sqrt((x - px)^2 + (y - py)^2)
            min_distance = math.min(min_distance, dist)
        end
        local inside_proximity = min_distance < 1.2  -- Very generous proximity
        
        -- Method 3: Flood-fill style check - count surrounding trail density
        local trail_density = 0
        local check_radius = 2
        for di = -check_radius, check_radius do
            for dj = -check_radius, check_radius do
                if di ~= 0 or dj ~= 0 then
                    local check_x, check_y = x + di * 0.5, y + dj * 0.5
                    for k = 1, #polygon - 1 do
                        local px, py = polygon[k].i, polygon[k].j
                        if math.sqrt((check_x - px)^2 + (check_y - py)^2) < 1.0 then
                            trail_density = trail_density + 1
                            break
                        end
                    end
                end
            end
        end
        local inside_density = trail_density >= 6  -- Surrounded by trail
        
        -- ULTRA-AGGRESSIVE: Return true if ANY method suggests inside
        return inside_ray or inside_proximity or inside_density
    end
    
    -- Enhanced corner detection algorithm with even more aggressive testing
    for i = math.max(1, minI - 3), math.min(self.width, maxI + 3) do
        for j = math.max(1, minJ - 3), math.min(self.height, maxJ + 3) do
            if self:isInside(i, j) and not self:isClaimed(i, j) then
                -- ULTRA-comprehensive point testing for MAXIMUM corner precision
                local test_points = {
                    {x = i, y = j},                     -- center
                    {x = i - 0.49, y = j - 0.49},       -- extreme top-left corner
                    {x = i + 0.49, y = j - 0.49},       -- extreme top-right corner  
                    {x = i - 0.49, y = j + 0.49},       -- extreme bottom-left corner
                    {x = i + 0.49, y = j + 0.49},       -- extreme bottom-right corner
                    {x = i, y = j - 0.49},              -- extreme top edge
                    {x = i, y = j + 0.49},              -- extreme bottom edge
                    {x = i - 0.49, y = j},              -- extreme left edge
                    {x = i + 0.49, y = j},              -- extreme right edge
                    {x = i - 0.35, y = j - 0.35},       -- inner top-left
                    {x = i + 0.35, y = j - 0.35},       -- inner top-right  
                    {x = i - 0.35, y = j + 0.35},       -- inner bottom-left
                    {x = i + 0.35, y = j + 0.35},       -- inner bottom-right
                    {x = i - 0.25, y = j - 0.25},       -- quarter top-left
                    {x = i + 0.25, y = j - 0.25},       -- quarter top-right
                    {x = i - 0.25, y = j + 0.25},       -- quarter bottom-left
                    {x = i + 0.25, y = j + 0.25},       -- quarter bottom-right
                    {x = i - 0.1, y = j - 0.1},         -- near center top-left
                    {x = i + 0.1, y = j - 0.1},         -- near center top-right
                    {x = i - 0.1, y = j + 0.1},         -- near center bottom-left
                    {x = i + 0.1, y = j + 0.1},         -- near center bottom-right
                    -- EXTRA CORNER TESTS for maximum precision
                    {x = i - 0.4, y = j - 0.4},         -- deep corner top-left
                    {x = i + 0.4, y = j - 0.4},         -- deep corner top-right
                    {x = i - 0.4, y = j + 0.4},         -- deep corner bottom-left
                    {x = i + 0.4, y = j + 0.4},         -- deep corner bottom-right
                    {x = i - 0.15, y = j - 0.15},       -- subtle top-left
                    {x = i + 0.15, y = j - 0.15},       -- subtle top-right
                    {x = i - 0.15, y = j + 0.15},       -- subtle bottom-left
                    {x = i + 0.15, y = j + 0.15}        -- subtle bottom-right
                }
                
                local inside_count = 0
                local corner_count = 0
                for _, point in ipairs(test_points) do
                    if isPointInPolygon(point.x, point.y, cleanTrail) then
                        inside_count = inside_count + 1
                        -- Extra weight for corner points
                        if math.abs(point.x - i) > 0.3 and math.abs(point.y - j) > 0.3 then
                            corner_count = corner_count + 1
                        end
                    end
                end
                
                -- ULTRA-AGGRESSIVE filling - multiple criteria for claiming cells
                local shouldClaim = false
                
                -- Criterion 1: Center point inside
                if isPointInPolygon(i, j, cleanTrail) then
                    shouldClaim = true
                end
                
                -- Criterion 2: Majority of test points inside
                if inside_count >= 15 then  -- More than half of 28 points
                    shouldClaim = true
                end
                
                -- Criterion 3: Strong corner presence
                if corner_count >= 4 then  -- Strong corner detection
                    shouldClaim = true
                end
                
                -- Criterion 4: Moderate presence with some corners
                if inside_count >= 8 and corner_count >= 2 then
                    shouldClaim = true
                end
                
                -- Criterion 5: ANY significant presence for edge cases
                if inside_count >= 4 then  -- VERY aggressive - even 4 points inside
                    shouldClaim = true
                end
                
                -- Criterion 6: SUPER AGGRESSIVE - if any corner points are inside, claim it
                if corner_count >= 1 then
                    shouldClaim = true
                end
                
                -- Criterion 7: HOLE PREVENTION - if mostly surrounded by claimed cells, claim it too
                local surrounding_claimed = 0
                local check_dirs = {{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,-1},{1,-1},{-1,1}}
                for _, dir in ipairs(check_dirs) do
                    local ni, nj = i + dir[1], j + dir[2]
                    if self:isInside(ni, nj) and self:isClaimed(ni, nj) then
                        surrounding_claimed = surrounding_claimed + 1
                    end
                end
                if surrounding_claimed >= 6 then  -- Surrounded by claimed cells
                    shouldClaim = true
                    if Config and Config.debug and Config.debug.enabled then print("Hole prevention: claiming cell surrounded by claimed cells") end
                end
                
                if shouldClaim and self.cells[i] and self.cells[i][j] == 'empty' then
                    self.cells[i][j] = 'claimed'
                    newlyClaimedCellCount = newlyClaimedCellCount + 1
                end
            end
        end
    end
    
    -- Mark trail cells as claimed (the border of the shape)
    for i = 1, #cleanTrail - 1 do  -- Don't process the duplicate closing point
        local cell = cleanTrail[i]
        if self:isInside(cell.i, cell.j) and self.cells[cell.i] then
            if self.cells[cell.i][cell.j] == 'trail' or self.cells[cell.i][cell.j] == 'empty' then
                self.cells[cell.i][cell.j] = 'claimed'
                newlyClaimedCellCount = newlyClaimedCellCount + 1
            end
        end
    end
    
    if Config and Config.debug and Config.debug.enabled then print("Advanced polygon closure completed with", newlyClaimedCellCount, "new cells") end
    
    -- ADDITIONAL: Flood fill enhancement to catch any missed enclosed areas
    local additionalCells = self:floodFillEnhancement(cleanTrail)
    newlyClaimedCellCount = newlyClaimedCellCount + additionalCells
    
    -- SUPER ADDITIONAL: Hole filling pass - fill any remaining holes
    local holeFillCells = self:fillRemainingHoles()
    newlyClaimedCellCount = newlyClaimedCellCount + holeFillCells
    
    if Config and Config.debug and Config.debug.enabled then print("Total cells claimed including all enhancements:", newlyClaimedCellCount) end
    
    -- ✅ CLOSURE LOGGING
    if Config and Config.debug and Config.debug.enabled then print("CLOSURE: claimedCells=" .. newlyClaimedCellCount .. " merged=" .. tostring(connectsToClaimed)) end
    
    -- Signal to Game that a zone was just closed
    self._zoneJustClosed = true
    
    -- ZONE MIRROR INTEGRATION: Record captured area for ability
    if newlyClaimedCellCount >= 5 then  -- Only record significant captures
        local capturedCells = {}
        -- Collect all newly claimed cells
        if self._recentlyClaimedCells then
            for _, cell in ipairs(self._recentlyClaimedCells) do
                table.insert(capturedCells, {i = cell.i, j = cell.j})
            end
        end
        
        -- Record in Zone Mirror ability (optional global)
        local zm = rawget(_G, 'ZoneMirror')
        if zm then
            zm:recordCapturedArea(capturedCells)
        elseif _G.currentGame then
            -- Try through game reference
            local ZoneMirror = require('src.abilities.zone_mirror')
            ZoneMirror:recordCapturedArea(capturedCells)
        end
    end
    
    return newlyClaimedCellCount
end

-- REVOLUTIONARY Flood Fill Enhancement - catches areas missed by polygon detection
function Grid:floodFillEnhancement(trail)
    if not trail or #trail < 3 then return 0 end
    
    local additionalCells = 0
    local visited = {}
    for i = 1, self.width do 
        visited[i] = {}
        for j = 1, self.height do
            visited[i][j] = false
        end
    end
    
    -- Find the bounding box of the trail
    local minI, maxI = math.huge, -math.huge
    local minJ, maxJ = math.huge, -math.huge
    for _, point in ipairs(trail) do
        minI, maxI = math.min(minI, point.i), math.max(maxI, point.i)
        minJ, maxJ = math.min(minJ, point.j), math.max(maxJ, point.j)
    end
    
    -- Expand bounds slightly to catch edge cases
    minI, maxI = math.max(1, minI - 2), math.min(self.width, maxI + 2)
    minJ, maxJ = math.max(1, minJ - 2), math.min(self.height, maxJ + 2)
    
    -- Mark all trail cells as barriers
    for _, point in ipairs(trail) do
        if inBounds(self, point.i, point.j) then
            visited[point.i][point.j] = true
        end
    end
    
    -- Start flood fill from borders of the bounding area
    local floodQueue = {}
    
    -- Add border cells of the expanded bounding box to flood queue
    for i = minI, maxI do
    if inBounds(self, i, minJ) and not visited[i][minJ] and not self:isClaimed(i, minJ) then
            table.insert(floodQueue, {i = i, j = minJ})
            visited[i][minJ] = true
        end
    if inBounds(self, i, maxJ) and not visited[i][maxJ] and not self:isClaimed(i, maxJ) then
            table.insert(floodQueue, {i = i, j = maxJ})
            visited[i][maxJ] = true
        end
    end
    
    for j = minJ, maxJ do
    if inBounds(self, minI, j) and not visited[minI][j] and not self:isClaimed(minI, j) then
            table.insert(floodQueue, {i = minI, j = j})
            visited[minI][j] = true
        end
    if inBounds(self, maxI, j) and not visited[maxI][j] and not self:isClaimed(maxI, j) then
            table.insert(floodQueue, {i = maxI, j = j})
            visited[maxI][j] = true
        end
    end
    
    -- Flood fill to mark all reachable empty cells from borders
    local head = 1
    local directions = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
    
    while head <= #floodQueue do
        local current = floodQueue[head]
        head = head + 1
        
        for _, dir in ipairs(directions) do
            local ni, nj = current.i + dir[1], current.j + dir[2]
            if inBounds(self, ni, nj) and not visited[ni][nj] and not self:isClaimed(ni, nj) then
                visited[ni][nj] = true
                table.insert(floodQueue, {i = ni, j = nj})
            end
        end
    end
    
    -- Any unvisited, unclaimed cell within bounds is enclosed - claim it!
    for i = minI, maxI do
        for j = minJ, maxJ do
            if inBounds(self, i, j) and not visited[i][j] and not self:isClaimed(i, j) then
                -- Skip outer border writes defensively
                if i ~= 1 and j ~= 1 and i ~= self.width and j ~= self.height then
                    if self.cells[i] then
                        self.cells[i][j] = 'claimed'
                    end
                end
                additionalCells = additionalCells + 1
            end
        end
    end

    return additionalCells
end

-- REVOLUTIONARY Hole Filling Algorithm - fills any remaining holes in claimed areas
function Grid:fillRemainingHoles()
    local holeCells = 0
    
    -- Multiple passes to catch all holes
    for pass = 1, 3 do
        local passCount = 0
        
        -- Check every cell to see if it's a hole (surrounded by claimed cells)
        for i = 2, self.width - 1 do
            for j = 2, self.height - 1 do
                if self:isInside(i, j) and not self:isClaimed(i, j) then
                    local surroundingClaimed = 0
                    local totalSurrounding = 0
                    
                    -- Check 8-directional neighborhood
                    local directions = {{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,-1},{1,-1},{-1,1}}
                    for _, dir in ipairs(directions) do
                        local ni, nj = i + dir[1], j + dir[2]
                        if self:isInside(ni, nj) then
                            totalSurrounding = totalSurrounding + 1
                            if self:isClaimed(ni, nj) then
                                surroundingClaimed = surroundingClaimed + 1
                            end
                        end
                    end
                    
                    -- If most neighbors are claimed, this is likely a hole - fill it
                    if surroundingClaimed >= 6 or (surroundingClaimed >= 5 and totalSurrounding <= 6) then
                        if self.cells[i] then
                            self.cells[i][j] = 'claimed'
                        end
                        passCount = passCount + 1
                        holeCells = holeCells + 1
                    end
                end
            end
        end
        
        if passCount == 0 then
            break  -- No more holes found
        end
    end

    return holeCells
end
---
-- Attempts to close an area based on a node trail (node-based).
-- @param nodeTrail List of node coordinates
-- @param player The player object
function Grid:closeAreaByNodes(nodeTrail, player)
    if not nodeTrail or #nodeTrail < 3 then return 0 end
    local newlyClaimedCellCount = 0
    local visited = {}
    for i = 1, self.width do visited[i] = {} end
    local q = {}
    -- 1. Mark all cells connected to border or enemies (not to be filled)
    if self.enemies and #self.enemies > 0 then
        for _, enemy in ipairs(self.enemies) do
            if self:isInside(enemy.i, enemy.j) then
                table.insert(q, {i=enemy.i, j=enemy.j})
                visited[enemy.i][enemy.j] = true
            end
        end
    end
    -- If no enemies, start from border
    if #q == 0 then
        for i = 1, self.width do
            if self:isInside(i,1) then table.insert(q, {i=i, j=1}); visited[i][1] = true end
            if self:isInside(i,self.height) then table.insert(q, {i=i, j=self.height}); visited[i][self.height] = true end
        end
        for j = 2, self.height-1 do
            if self:isInside(1,j) then table.insert(q, {i=1, j=j}); visited[1][j] = true end
            if self:isInside(self.width,j) then table.insert(q, {i=self.width, j=j}); visited[self.width][j] = true end
        end
    end
    -- 1.5: Mark all trail cells as border (not to be filled)
    for _, node in ipairs(nodeTrail) do
        local ci, cj = node.i, node.j
        if self:isInside(ci, cj) then
            visited[ci][cj] = true
        end
    end
    -- 2. BFS: Mark all cells reachable from border/enemies/trail as not to be filled
    local head = 1
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    while head <= #q do
        local curr = q[head]
        head = head + 1
        for _, d in ipairs(dirs) do
            local ni, nj = curr.i + d[1], curr.j + d[2]
            if inBounds(self, ni, nj) and not visited[ni][nj] and self.cells[ni] and self.cells[ni][nj] ~= 'claimed' then
                visited[ni][nj] = true
                table.insert(q, {i=ni, j=nj})
            end
        end
    end
    -- 3. Any cell not visited and not claimed is a closed zone! Fill it and check for enemies
    local closedCells = {}
    local enemiesToPowerups = {}
    for i = 2, self.width-1 do
        for j = 2, self.height-1 do
            if not visited[i][j] and self.cells[i] and self.cells[i][j] ~= 'claimed' then
                -- Do not overwrite explicit border cells
                if i ~= 1 and j ~= 1 and i ~= self.width and j ~= self.height then
                    self.cells[i][j] = 'claimed'
                end
                newlyClaimedCellCount = newlyClaimedCellCount + 1
                table.insert(closedCells, {i=i, j=j})
                -- Check for enemy in this cell
                if self.enemies then
                    for idx, enemy in ipairs(self.enemies) do
                        if enemy.i == i and enemy.j == j then
                            table.insert(enemiesToPowerups, idx)
                        end
                    end
                end
            end
        end
    end
    -- Turn captured enemies into powerups
    if #enemiesToPowerups > 0 then
        local PowerUp = require('src.powerups.base')
        for n = #enemiesToPowerups, 1, -1 do
            local idx = enemiesToPowerups[n]
            local enemy = table.remove(self.enemies, idx)
            local powerup = PowerUp:new(enemy.i, enemy.j)
            self.powerups = self.powerups or {}
            table.insert(self.powerups, powerup)
        end
    end
    -- 4. Visual effect for closed area
    self._recentlyClaimedCells = self._recentlyClaimedCells or {}
    self._recentlyClaimedTimer = self._recentlyClaimedTimer or 0
    self._recentlyClaimedDuration = self._recentlyClaimedDuration or 0.4
    self._recentlyClaimedCells = closedCells
    self._recentlyClaimedTimer = self._recentlyClaimedDuration
    -- 5. Also claim the trail itself
    for _, node in ipairs(nodeTrail) do
        local ci, cj = node.i, node.j
        if self:isInside(ci, cj) and self.cells[ci] and self.cells[ci][cj] ~= 'claimed' then
            -- Skip writing on outer frame
            if ci ~= 1 and cj ~= 1 and ci ~= self.width and cj ~= self.height then
                self.cells[ci][cj] = 'claimed'
            end
        end
    end
    -- After closure, fix diagonal corners for smoothness
    local function fix_diagonal_corners()
        for i=2, self.width-1 do
            for j=2, self.height-1 do
                if self.cells[i] and self.cells[i][j] == 'claimed' then
                    for _,d in ipairs({{1,1},{-1,1},{1,-1},{-1,-1}}) do
                        local ni, nj = i+d[1], j+d[2]
                        if self:isInside(ni, nj) and self.cells[ni] and self.cells[ni][nj] ~= 'claimed' then
                            if self.cells[i] and self.cells[i][nj] == 'claimed' and self.cells[ni] and self.cells[ni][j] == 'claimed' then
                                self.cells[ni][nj] = 'claimed'
                            end
                        end
                    end
                end
            end
        end
    end
    fix_diagonal_corners()
    
    -- Notify game that territory was claimed (to relocate enemies)
    if newlyClaimedCellCount > 0 and self.onTerritoryClaimed then
        self.onTerritoryClaimed()
    end
    
    return newlyClaimedCellCount
end

---
-- Checks if a trail segment blocks movement between two cells.
function Grid:isTrailSegmentBetween(n1, n2, c1_i, c1_j, c2_i, c2_j)
    -- Remove all print statements from this function for performance
    if (n1.i == n2.i and n1.j == n2.j) then
        return false
    end
    local cell_move_horizontal = (c1_j == c2_j)
    local cell_move_vertical = (c1_i == c2_i)
    local trail_seg_horizontal = (n1.j == n2.j)
    local trail_seg_vertical = (n1.i == n2.i)
    local trail_seg_diagonal = (math.abs(n1.i - n2.i) == 1 and math.abs(n1.j - n2.j) == 1)
    local p1_i, p1_j, p2_i, p2_j
    if cell_move_horizontal then
        p1_i = math.max(c1_i, c2_i); p1_j = c1_j;
        p2_i = math.max(c1_i, c2_i); p2_j = c1_j + 1;
    elseif cell_move_vertical then
        p1_i = c1_i;       p1_j = math.max(c1_j, c2_j);
        p2_i = c1_i + 1;   p2_j = math.max(c1_j, c2_j);
    else
        return false
    end
    if (trail_seg_horizontal and cell_move_vertical) or (trail_seg_vertical and cell_move_horizontal) then
        if trail_seg_vertical then
            if n1.i == p1_i then
                local y_trail_min = math.min(n1.j, n2.j)
                local y_trail_max = math.max(n1.j, n2.j)
                local y_interface_min = math.min(p1_j, p2_j)
                local y_interface_max = math.max(p1_j, p2_j)
                if math.max(y_trail_min, y_interface_min) < math.min(y_trail_max, y_interface_max) then
                    return true
                end
            end
        elseif trail_seg_horizontal then
            if n1.j == p1_j then
                local x_trail_min = math.min(n1.i, n2.i)
                local x_trail_max = math.max(n1.i, n2.i)
                local x_interface_min = math.min(p1_i, p2_i)
                local x_interface_max = math.max(p1_i, p2_i)
                if math.max(x_trail_min, x_interface_min) < math.min(x_trail_max, x_interface_max) then
                    return true
                end
            end
        end
    elseif (trail_seg_vertical and cell_move_vertical) or (trail_seg_horizontal and cell_move_horizontal) then
        local intersection_node_i, intersection_node_j
        if trail_seg_vertical then
            intersection_node_i = n1.i
            intersection_node_j = p1_j
            local min_ny = math.min(n1.j, n2.j)
            local max_ny = math.max(n1.j, n2.j)
            local min_px = math.min(p1_i, p2_i)
            local max_px = math.max(p1_i, p2_i)
            if intersection_node_i >= min_px and intersection_node_i <= max_px and
               intersection_node_j >= min_ny and intersection_node_j <= max_ny then
                return true
            end
        else
            intersection_node_i = p1_i
            intersection_node_j = n1.j
            local min_nx = math.min(n1.i, n2.i)
            local max_nx = math.max(n1.i, n2.i)
            local min_py = math.min(p1_j, p2_j)
            local max_py = math.max(p1_j, p2_j)
            if intersection_node_j >= min_py and intersection_node_j <= max_py and
               intersection_node_i >= min_nx and intersection_node_i <= max_nx then
                return true
            end
        end
    end
    if trail_seg_diagonal then
        local shared_node_i, shared_node_j
        local other_trail_node_i, other_trail_node_j
        local other_interface_node_i, other_interface_node_j
        local found_shared_node = false
        if n1.i == p1_i and n1.j == p1_j then
            shared_node_i, shared_node_j = n1.i, n1.j; other_trail_node_i, other_trail_node_j = n2.i, n2.j; other_interface_node_i, other_interface_node_j = p2_i, p2_j; found_shared_node = true;
        elseif n1.i == p2_i and n1.j == p2_j then
            shared_node_i, shared_node_j = n1.i, n1.j; other_trail_node_i, other_trail_node_j = n2.i, n2.j; other_interface_node_i, other_interface_node_j = p1_i, p1_j; found_shared_node = true;
        elseif n2.i == p1_i and n2.j == p1_j then
            shared_node_i, shared_node_j = n2.i, n2.j; other_trail_node_i, other_trail_node_j = n1.i, n1.j; other_interface_node_i, other_interface_node_j = p2_i, p2_j; found_shared_node = true;
        elseif n2.i == p2_i and n2.j == p2_j then
            shared_node_i, shared_node_j = n2.i, n2.j; other_trail_node_i, other_trail_node_j = n1.i, n1.j; other_interface_node_i, other_interface_node_j = p1_i, p1_j; found_shared_node = true;
        end
        if found_shared_node then
            local v_trail_i = other_trail_node_i - shared_node_i
            local v_trail_j = other_trail_node_j - shared_node_j
            local v_interface_i = other_interface_node_i - shared_node_i
            local v_interface_j = other_interface_node_j - shared_node_j
            local cross_product = (v_trail_i * v_interface_j - v_trail_j * v_interface_i)
            if cross_product ~= 0 then
                return true
            end
        end
    end
    return false
end

---
-- Claims a list of bonus cells (e.g., from powerups).
function Grid:addBonusClaimedCells(bonusCells)
    if not bonusCells or #bonusCells == 0 then
        return 0
    end
    local actuallyClaimedCount = 0
    for _, cell in ipairs(bonusCells) do
        if self:isInside(cell.i, cell.j) and self.cells[cell.i][cell.j] ~= 'claimed' then
            self.cells[cell.i][cell.j] = 'claimed'
            actuallyClaimedCount = actuallyClaimedCount + 1
        end
    end
    return actuallyClaimedCount
end

---
-- Sets the required percent of claimed area to win the level.
function Grid:setRequiredClaimedPercent(p)
    self.requiredClaimedPercent = p
end

---
-- Dynamically sets grid size to fit the window.
function Grid:setSizeToWindow(ww, wh, margin, reservedRightPx)
    -- Compute playable rect that excludes the right pane and respects margins
    margin = margin or 16
    reservedRightPx = reservedRightPx or 0

    local playableLeft = margin
    local playableRight = ww - reservedRightPx - margin
    local playableTop = margin
    local playableBottom = wh - margin

    local playableW = math.max(0, playableRight - playableLeft)
    local playableH = math.max(0, playableBottom - playableTop)

    -- Target cell counts for a larger-feeling map
    local targetGridW = 90
    local targetGridH = 52

    -- Cell size derived from playable area and target counts; enforce minimum size
    local csW = math.floor(playableW / targetGridW)
    local csH = math.floor(playableH / targetGridH)
    self.cellSize = math.max(6, math.min(csW, csH))

    -- Derive actual grid dimensions in cells from playable area and chosen cellSize
    self.width = math.max(4, math.floor(playableW / self.cellSize))
    self.height = math.max(4, math.floor(playableH / self.cellSize))
    self.nodeWidth = self.width + 1
    self.nodeHeight = self.height + 1

    local actualGridPixelWidth = self.width * self.cellSize
    local actualGridPixelHeight = self.height * self.cellSize

    -- Center the grid inside the playable rect
    self.offsetX = playableLeft + math.floor((playableW - actualGridPixelWidth) / 2)
    self.offsetY = playableTop + math.floor((playableH - actualGridPixelHeight) / 2)
end

---
-- Returns the percent of the grid that is claimed.
function Grid:getClaimedPercent()
    local claimed, total = 0, 0
    if not self.cells or not self.width or not self.height then return 0 end
    for i = 2, self.width-1 do
        if self.cells[i] == nil then self.cells[i] = {} end
        for j = 2, self.height-1 do
            total = total + 1
            if self.cells[i][j] == nil then goto continue_inner_loop end
            if self.cells[i][j] == 'claimed' then
                claimed = claimed + 1
            end
            ::continue_inner_loop::
        end
        ::continue_outer_loop::
    end
    if total == 0 then return 0 end -- Avoid division by zero
    return claimed / total
end

---
-- Checks if a node is valid (within grid bounds).
function Grid:isNodeValid(node_i, node_j)
    if not self.nodeWidth or not self.nodeHeight then
        print("Error: Grid nodeWidth or nodeHeight not initialized before isNodeValid call.")
        return false
    end
    return node_i >= 1 and node_i <= self.nodeWidth and node_j >= 1 and node_j <= self.nodeHeight
end

---
-- Checks if a line between two nodes is safe (on the border or between claimed cells or virtual border)
function Grid:isLineSafe(prev_node_i, prev_node_j, next_node_i, next_node_j)
    if not self.nodeWidth or not self.nodeHeight or not self.width or not self.height then
        print("Error: Grid dimensions not initialized before isLineSafe call.")
        return false
    end
    -- Horizontal segment
    if prev_node_j == next_node_j then
        local node_j = prev_node_j
        if node_j == 1 or node_j == self.nodeHeight then
            return true
        end
        if self:isOnVirtualBorder(next_node_i, next_node_j) then
            return true
        end
        local cell_i_idx = math.min(prev_node_i, next_node_i)
        local cell_above_ok = self:isInside(cell_i_idx, node_j - 1) and self:isClaimed(cell_i_idx, node_j - 1)
        local cell_below_ok = self:isInside(cell_i_idx, node_j)     and self:isClaimed(cell_i_idx, node_j)
        return cell_above_ok and cell_below_ok
    elseif prev_node_i == next_node_i then
        local node_i = prev_node_i
        if node_i == 1 or node_i == self.nodeWidth then
            return true
        end
        if self:isOnVirtualBorder(next_node_i, next_node_j) then
            return true
        end
        local cell_j_idx = math.min(prev_node_j, next_node_j)
        local cell_left_ok  = self:isInside(node_i - 1, cell_j_idx) and self:isClaimed(node_i - 1, cell_j_idx)
        local cell_right_ok = self:isInside(node_i, cell_j_idx)     and self:isClaimed(node_i, cell_j_idx)
        return cell_left_ok and cell_right_ok
    end
    print(string.format("Warning: isLineSafe called with non-orthogonal or zero-length segment N(%d,%d)-N(%d,%d)", prev_node_i, prev_node_j, next_node_i, next_node_j))
    return false
end

---
-- Checks if a node is on the virtual border (for area closure).
function Grid:isOnVirtualBorder(i, j)
    -- Define a 4x4 center as a virtual border (can be adjusted)
    local midW, midH = math.floor(self.nodeWidth/2), math.floor(self.nodeHeight/2)
    return (i >= midW-1 and i <= midW+2 and j >= midH-1 and j <= midH+2)
end

-- Highlight effect for recently claimed cells
-- Grid._recentlyClaimedCells: table of cells
-- Grid._recentlyClaimedTimer: timer for highlight effect
-- Grid._recentlyClaimedDuration: duration of highlight effect

---
-- Resets the grid partially, keeping a percentage of claimed territory
-- @param keepPercent Percentage of claimed territory to keep (0.0 to 1.0)
function Grid:resetPartial(keepPercent)
    keepPercent = keepPercent or 0.0
    
    -- Collect all claimed cells
    local claimedCells = {}
    for i = 2, self.width - 1 do
        for j = 2, self.height - 1 do
            if self.cells[i] and self.cells[i][j] == 'claimed' then
                table.insert(claimedCells, {i = i, j = j})
            end
        end
    end
    
    -- Calculate how many to keep
    local numToKeep = math.floor(#claimedCells * keepPercent)
    
    -- Randomly select cells to reset to empty
    for k = numToKeep + 1, #claimedCells do
        local cell = claimedCells[k]
        if self.cells[cell.i] then
            self.cells[cell.i][cell.j] = 'empty'
        end
    end
    
    -- Clear any trails
    for i = 1, self.width do
        if self.cells[i] then
            for j = 1, self.height do
                if self.cells[i][j] == 'trail' then
                    self.cells[i][j] = 'empty'
                end
            end
        end
    end
    
    if Config and Config.debug and Config.debug.enabled then print("Grid partially reset - kept", numToKeep, "out of", #claimedCells, "claimed cells") end
end

-- Mark cells in a specific area as completed target shape (green)
function Grid:markTargetShapeCompleted(cellTrail)
    if not cellTrail or #cellTrail == 0 then return end
    
    -- Find the bounding box of the drawn shape
    local minI, maxI = cellTrail[1].i, cellTrail[1].i
    local minJ, maxJ = cellTrail[1].j, cellTrail[1].j
    
    for _, cell in ipairs(cellTrail) do
        minI = math.min(minI, cell.i)
        maxI = math.max(maxI, cell.i)
        minJ = math.min(minJ, cell.j)
        maxJ = math.max(maxJ, cell.j)
    end
    
    -- Mark all claimed cells within the bounding box as target_completed
    for i = minI, maxI do
        for j = minJ, maxJ do
            if self.cells[i] and self.cells[i][j] == 'claimed' then
                -- Use simple point-in-polygon check or just mark the general area
                self.cells[i][j] = 'target_completed'
            end
        end
    end
    
    if Config and Config.debug and Config.debug.enabled then
        local area = (maxI - minI + 1) * (maxJ - minJ + 1)
        print("Marked target shape area as green - bounding box:", minI, minJ, "to", maxI, maxJ, "area:", area)
    end
end

return Grid
