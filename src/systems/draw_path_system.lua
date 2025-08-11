-- src/systems/draw_path_system.lua
-- Tracks player trail path for shape drawing challenges

local DrawPathSystem = {}
local Config = nil
do
    local ok, cfg = pcall(require, 'src.config')
    if ok then Config = cfg end
end

-- Constructor for instance-based usage
function DrawPathSystem:new()
    local o = {}
    setmetatable(o, { __index = self })
    o:init()
    -- grid reference to be set by owner (Game) after creation
    return o
end

function DrawPathSystem:init()
    self.currentPath = {}           -- Current drawing path
    self.isDrawing = false          -- Whether currently drawing
    self.drawStartTime = 0          -- When drawing started
    self.lastPoint = nil            -- Last recorded point
    self.minDistanceThreshold = 2   -- Minimum distance between recorded points
    self.maxDrawTime = 30           -- Maximum time allowed for drawing (seconds)
    self.pathColor = {1, 0.8, 0.2, 0.8} -- Yellow path color
    self.previewColor = {0.5, 0.5, 0.5, 0.5} -- Gray preview color
    self.grid = nil                 -- Optional grid reference for clamping
end

-- Reset current state
function DrawPathSystem:reset()
    self.currentPath = {}
    self.isDrawing = false
    self.drawStartTime = 0
    self.lastPoint = nil
end

-- Start drawing a new path
function DrawPathSystem:startDrawing(startX, startY)
    self.currentPath = {}
    self.isDrawing = true
    self.drawStartTime = love.timer.getTime()
    self.lastPoint = {x = startX, y = startY}
    table.insert(self.currentPath, {x = startX, y = startY, timestamp = self.drawStartTime})
    if Config and Config.debug and Config.debug.enabled then
        print("Started drawing shape at", startX, startY)
    end
end

-- Aliases to support requested API
function DrawPathSystem:startPath(x, y)
    return self:startDrawing(x, y)
end

-- Add point to current path
function DrawPathSystem:addPoint(x, y)
    if not self.isDrawing then return false end
    
    -- Check if we've exceeded max draw time
    local currentTime = love.timer.getTime()
    if currentTime - self.drawStartTime > self.maxDrawTime then
        self:cancelDrawing()
        return false
    end
    
    -- If we have a grid, convert to node and discard out-of-bounds
    if self.grid then
        local g = self.grid
        local ni = math.floor((x - g.offsetX) / g.cellSize + 0.5) + 1
        local nj = math.floor((y - g.offsetY) / g.cellSize + 0.5) + 1
        if ni < 1 or nj < 1 or ni > g.nodeWidth or nj > g.nodeHeight then
            return false -- discard points outside grid nodes
        end
        -- Optionally clamp pixel to the center of the clamped node for visual consistency
        x = g.offsetX + (ni - 1) * g.cellSize + g.cellSize/2
        y = g.offsetY + (nj - 1) * g.cellSize + g.cellSize/2
    end
    
    -- Only add point if it's far enough from the last point
    if self.lastPoint then
        local distance = math.sqrt((x - self.lastPoint.x)^2 + (y - self.lastPoint.y)^2)
        if distance < self.minDistanceThreshold then
            return false -- Too close to last point
        end
    end
    
    self.lastPoint = {x = x, y = y}
    table.insert(self.currentPath, {x = x, y = y, timestamp = currentTime})
    return true
end

-- Finish drawing and return the completed path
function DrawPathSystem:finishDrawing()
    if not self.isDrawing or #self.currentPath < 3 then
        return nil -- Not enough points for a shape
    end
    
    local completedPath = {}
    for _, point in ipairs(self.currentPath) do
        table.insert(completedPath, {x = point.x, y = point.y})
    end
    
    self.isDrawing = false
    local drawTime = love.timer.getTime() - self.drawStartTime
    
    if Config and Config.debug and Config.debug.enabled then
        print("Finished drawing shape with", #completedPath, "points in", math.floor(drawTime * 10) / 10, "seconds")
    end
    
    return {
        points = completedPath,
        drawTime = drawTime,
        pointCount = #completedPath
    }
end

function DrawPathSystem:finishPath()
    return self:finishDrawing()
end

-- Cancel current drawing
function DrawPathSystem:cancelDrawing()
    if self.isDrawing then
        if Config and Config.debug and Config.debug.enabled then print("Drawing cancelled") end
    end
    self.currentPath = {}
    self.isDrawing = false
    self.lastPoint = nil
end

-- Get current drawing progress
function DrawPathSystem:getDrawingProgress()
    if not self.isDrawing then
        return {isDrawing = false}
    end
    
    local currentTime = love.timer.getTime()
    local elapsedTime = currentTime - self.drawStartTime
    local timeRemaining = math.max(0, self.maxDrawTime - elapsedTime)
    
    return {
        isDrawing = true,
        pointCount = #self.currentPath,
        elapsedTime = elapsedTime,
        timeRemaining = timeRemaining,
        timeProgress = elapsedTime / self.maxDrawTime
    }
end

-- Draw the current path
function DrawPathSystem:draw()
    if not self.currentPath or #self.currentPath < 2 then return end
    
    local lw = 3
    if self.grid and self.grid.cellSize then
        lw = math.max(2, math.floor(self.grid.cellSize * 0.22))
    end
    love.graphics.setLineWidth(lw)
    love.graphics.setColor(self.pathColor)
    
    -- Draw lines between consecutive points
    for i = 1, #self.currentPath - 1 do
        local p1 = self.currentPath[i]
        local p2 = self.currentPath[i + 1]
        
        -- Convert to screen coordinates if needed
    local x1, y1 = p1.x, p1.y
    local x2, y2 = p2.x, p2.y
        love.graphics.line(x1, y1, x2, y2)
    end
    
    -- Draw points as small circles
    love.graphics.setColor(self.pathColor[1], self.pathColor[2], self.pathColor[3], self.pathColor[4] * 1.5)
    for _, point in ipairs(self.currentPath) do
        local pr = math.max(1, math.floor(lw * 0.33))
        love.graphics.circle("fill", point.x, point.y, pr)
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
    love.graphics.setLineWidth(1) -- Reset line width
end

-- Draw a template shape as preview/guide
function DrawPathSystem:drawTemplate(template, grid, alpha)
    if not template or not template.points or #template.points < 2 then return end
    
    alpha = alpha or 0.5
    love.graphics.setLineWidth(2)
    love.graphics.setColor(self.previewColor[1], self.previewColor[2], self.previewColor[3], alpha)
    
    -- Draw template outline
    for i = 1, #template.points - 1 do
        local p1 = template.points[i]
        local p2 = template.points[i + 1]
        
        local x1, y1 = p1.x, p1.y
        local x2, y2 = p2.x, p2.y
        
        if grid and grid.getNodePixelPosition then
            x1, y1 = grid:getNodePixelPosition(p1.x, p1.y)
            x2, y2 = grid:getNodePixelPosition(p2.x, p2.y)
        end
        
        love.graphics.line(x1, y1, x2, y2)
    end
    
    -- Draw template points
    love.graphics.setColor(self.previewColor[1], self.previewColor[2], self.previewColor[3], alpha * 0.8)
    for _, point in ipairs(template.points) do
        local x, y = point.x, point.y
        if grid and grid.getNodePixelPosition then
            x, y = grid:getNodePixelPosition(point.x, point.y)
        end
        love.graphics.circle("fill", x, y, 2)
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
    love.graphics.setLineWidth(1) -- Reset line width
end

-- Simplify path by removing redundant points
function DrawPathSystem:simplifyPath(path, tolerance)
    tolerance = tolerance or 5 -- Default tolerance
    if not path or #path < 3 then return path end
    
    local simplified = {path[1]} -- Always keep first point
    
    for i = 2, #path - 1 do
        local prev = simplified[#simplified]
        local current = path[i]
        local next = path[i + 1]
        
        -- Calculate distance from current point to line between prev and next
        local distance = self:pointToLineDistance(current, prev, next)
        
        if distance > tolerance then
            table.insert(simplified, current) -- Keep this point
        end
    end
    
    table.insert(simplified, path[#path]) -- Always keep last point
    return simplified
end

-- Calculate distance from point to line segment
function DrawPathSystem:pointToLineDistance(point, lineStart, lineEnd)
    local A = point.x - lineStart.x
    local B = point.y - lineStart.y
    local C = lineEnd.x - lineStart.x
    local D = lineEnd.y - lineStart.y
    
    local dot = A * C + B * D
    local lenSq = C * C + D * D
    
    if lenSq == 0 then
        return math.sqrt(A * A + B * B) -- Line is a point
    end
    
    local param = dot / lenSq
    local xx, yy
    
    if param < 0 then
        xx, yy = lineStart.x, lineStart.y
    elseif param > 1 then
        xx, yy = lineEnd.x, lineEnd.y
    else
        xx = lineStart.x + param * C
        yy = lineStart.y + param * D
    end
    
    local dx = point.x - xx
    local dy = point.y - yy
    return math.sqrt(dx * dx + dy * dy)
end

-- Get path bounds (for normalization)
function DrawPathSystem:getPathBounds(path)
    if not path or #path == 0 then return nil end
    
    local minX, minY = path[1].x, path[1].y
    local maxX, maxY = path[1].x, path[1].y
    
    for _, point in ipairs(path) do
        minX = math.min(minX, point.x)
        minY = math.min(minY, point.y)
        maxX = math.max(maxX, point.x)
        maxY = math.max(maxY, point.y)
    end
    
    return {
        minX = minX, minY = minY,
        maxX = maxX, maxY = maxY,
        width = maxX - minX,
        height = maxY - minY
    }
end

-- Normalize path to 0-1 coordinate space
function DrawPathSystem:normalizePath(path)
    local bounds = self:getPathBounds(path)
    if not bounds or bounds.width == 0 or bounds.height == 0 then
        return path
    end
    
    local normalized = {}
    for _, point in ipairs(path) do
        table.insert(normalized, {
            x = (point.x - bounds.minX) / bounds.width,
            y = (point.y - bounds.minY) / bounds.height
        })
    end
    
    return normalized
end

return DrawPathSystem
