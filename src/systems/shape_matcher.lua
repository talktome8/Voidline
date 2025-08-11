-- src/systems/shape_matcher.lua
-- Compares player-drawn paths to template shapes and calculates accuracy

local ShapeMatcher = {}

function ShapeMatcher:init()
    self.matchMethods = {
        "path_similarity",     -- Compare path vectors
        "area_overlap",        -- Compare filled areas
        "structural_match"     -- Compare angles and edges
    }
    self.currentMethod = "path_similarity" -- Default method
end

-- Main matching function - returns match result
function ShapeMatcher:matchShape(playerPath, template)
    if not playerPath or not template or not playerPath.points or not template.points then
        return {
            accuracy = 0,
            method = "none",
            details = "Invalid input data"
        }
    end
    
    -- Normalize both paths for comparison
    local normalizedPlayer = self:normalizePath(playerPath.points)
    local normalizedTemplate = self:normalizePath(template.points)
    
    -- Use the selected matching method
    local result = nil
    if self.currentMethod == "path_similarity" then
        result = self:pathSimilarityMatch(normalizedPlayer, normalizedTemplate, template)
    elseif self.currentMethod == "area_overlap" then
        result = self:areaOverlapMatch(normalizedPlayer, normalizedTemplate, template)
    elseif self.currentMethod == "structural_match" then
        result = self:structuralMatch(normalizedPlayer, normalizedTemplate, template)
    else
        result = self:pathSimilarityMatch(normalizedPlayer, normalizedTemplate, template) -- Default
    end
    
    -- Add bonus factors
    result = self:applyBonusFactors(result, playerPath, template)
    
    return result
end

-- Method 1: Enhanced Path Similarity (vector comparison with rotation tolerance)
function ShapeMatcher:pathSimilarityMatch(playerPath, templatePath, template)
    if not playerPath or not templatePath or #playerPath == 0 or #templatePath == 0 then
        return { accuracy = 0, method = "path_similarity", details = "Empty paths" }
    end
    
    -- Resample both paths to same point count for comparison
    local targetPoints = 32  -- Higher resolution for better matching
    local resampledPlayer = self:resamplePath(playerPath, targetPoints)
    local resampledTemplate = self:resamplePath(templatePath, targetPoints)
    
    -- Test multiple rotations to find best match (rotation-invariant)
    local bestAccuracy = 0
    local bestRotation = 0
    
    for rotation = 0, 2 * math.pi, math.pi / 8 do  -- Test 16 rotations
        local rotatedTemplate = self:rotatePath(resampledTemplate, rotation)
        local accuracy = self:comparePathVectors(resampledPlayer, rotatedTemplate)
        
        if accuracy > bestAccuracy then
            bestAccuracy = accuracy
            bestRotation = rotation
        end
    end
    
    -- Apply shape-specific bonuses
    local shapeBonus = 1.0
    if template.type == "triangle" and self:hasTriangleCharacteristics(playerPath) then
        shapeBonus = 1.2
    elseif template.type == "square" and self:hasSquareCharacteristics(playerPath) then
        shapeBonus = 1.15
    elseif template.type == "circle" and self:hasCircleCharacteristics(playerPath) then
        shapeBonus = 1.1
    end
    
    bestAccuracy = bestAccuracy * shapeBonus
    
    return {
        accuracy = math.min(1.0, bestAccuracy),
        method = "path_similarity",
        details = {
            bestRotation = bestRotation,
            shapeBonus = shapeBonus,
            rawAccuracy = bestAccuracy / shapeBonus
        }
    }
end

-- Method 2: Area Overlap (filled area comparison)
function ShapeMatcher:areaOverlapMatch(playerPath, templatePath, template)
    local gridSize = 50 -- Resolution for area calculation
    local playerArea = self:calculatePathArea(playerPath, gridSize)
    local templateArea = self:calculatePathArea(templatePath, gridSize)
    
    -- Calculate intersection and union
    local intersection = 0
    local union = 0
    
    for i = 1, gridSize do
        for j = 1, gridSize do
            local playerHas = playerArea[i] and playerArea[i][j]
            local templateHas = templateArea[i] and templateArea[i][j]
            
            if playerHas and templateHas then
                intersection = intersection + 1
            end
            if playerHas or templateHas then
                union = union + 1
            end
        end
    end
    
    -- Jaccard similarity (intersection over union)
    local accuracy = union > 0 and (intersection / union) or 0
    
    return {
        accuracy = accuracy,
        method = "area_overlap",
        details = {
            intersection = intersection,
            union = union,
            playerAreaSize = self:countAreaCells(playerArea),
            templateAreaSize = self:countAreaCells(templateArea)
        }
    }
end

-- Method 3: Structural Match (angles and edges)
function ShapeMatcher:structuralMatch(playerPath, templatePath, template)
    local playerAngles = self:calculatePathAngles(playerPath)
    local templateAngles = self:calculatePathAngles(templatePath)
    
    -- Compare angle sequences
    local angleAccuracy = self:compareAngleSequences(playerAngles, templateAngles)
    
    -- Compare edge lengths (normalized)
    local playerLengths = self:calculateEdgeLengths(playerPath)
    local templateLengths = self:calculateEdgeLengths(templatePath)
    local lengthAccuracy = self:compareEdgeLengths(playerLengths, templateLengths)
    
    -- Combine angle and length accuracy
    local accuracy = (angleAccuracy * 0.7) + (lengthAccuracy * 0.3)
    
    return {
        accuracy = accuracy,
        method = "structural_match",
        details = {
            angleAccuracy = angleAccuracy,
            lengthAccuracy = lengthAccuracy,
            playerAngles = #playerAngles,
            templateAngles = #templateAngles
        }
    }
end

-- Helper: Normalize path to 0-1 coordinate space
function ShapeMatcher:normalizePath(path)
    if not path or #path < 2 then return path end
    
    local minX, minY = path[1].x, path[1].y
    local maxX, maxY = path[1].x, path[1].y
    
    -- Find bounds
    for _, point in ipairs(path) do
        minX = math.min(minX, point.x)
        minY = math.min(minY, point.y)
        maxX = math.max(maxX, point.x)
        maxY = math.max(maxY, point.y)
    end
    
    local width = maxX - minX
    local height = maxY - minY
    
    -- Avoid division by zero
    if width == 0 then width = 1 end
    if height == 0 then height = 1 end
    
    -- Normalize points
    local normalized = {}
    for _, point in ipairs(path) do
        table.insert(normalized, {
            x = (point.x - minX) / width,
            y = (point.y - minY) / height
        })
    end
    
    return normalized
end

-- Helper: Resample path to have specific number of points
function ShapeMatcher:resamplePath(path, targetPoints)
    if not path or #path < 2 then return path end
    if #path >= targetPoints then return path end
    
    local resampled = {}
    local totalLength = 0
    local segmentLengths = {}
    
    -- Calculate total path length and segment lengths
    for i = 1, #path - 1 do
        local length = math.sqrt(
            (path[i + 1].x - path[i].x)^2 + 
            (path[i + 1].y - path[i].y)^2
        )
        table.insert(segmentLengths, length)
        totalLength = totalLength + length
    end
    
    if totalLength == 0 then return path end
    
    -- Resample points along the path
    local stepLength = totalLength / (targetPoints - 1)
    table.insert(resampled, path[1]) -- Always include first point
    
    local currentLength = 0
    local targetLength = stepLength
    
    for i = 1, #segmentLengths do
        local segmentStart = path[i]
        local segmentEnd = path[i + 1]
        local segmentLength = segmentLengths[i]
        
        while targetLength <= currentLength + segmentLength and #resampled < targetPoints - 1 do
            -- Interpolate point along this segment
            local t = (targetLength - currentLength) / segmentLength
            local newPoint = {
                x = segmentStart.x + t * (segmentEnd.x - segmentStart.x),
                y = segmentStart.y + t * (segmentEnd.y - segmentStart.y)
            }
            table.insert(resampled, newPoint)
            targetLength = targetLength + stepLength
        end
        
        currentLength = currentLength + segmentLength
    end
    
    table.insert(resampled, path[#path]) -- Always include last point
    return resampled
end

-- Helper: Calculate filled area for path
function ShapeMatcher:calculatePathArea(path, gridSize)
    local area = {}
    for i = 1, gridSize do
        area[i] = {}
    end
    
    if not path or #path < 3 then return area end
    
    -- Use ray casting to determine inside/outside for each grid cell
    for i = 1, gridSize do
        for j = 1, gridSize do
            local x = (i - 1) / (gridSize - 1)
            local y = (j - 1) / (gridSize - 1)
            
            if self:pointInPolygon(x, y, path) then
                area[i][j] = true
            end
        end
    end
    
    return area
end

-- Helper: Point in polygon test (ray casting)
function ShapeMatcher:pointInPolygon(x, y, polygon)
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

-- Helper: Count filled cells in area
function ShapeMatcher:countAreaCells(area)
    local count = 0
    for i = 1, #area do
        if area[i] then
            for j = 1, #area[i] do
                if area[i][j] then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- Helper: Calculate angles at each point in path
function ShapeMatcher:calculatePathAngles(path)
    if not path or #path < 3 then return {} end
    
    local angles = {}
    for i = 2, #path - 1 do
        local p1 = path[i - 1]
        local p2 = path[i]
        local p3 = path[i + 1]
        
        local v1 = {x = p2.x - p1.x, y = p2.y - p1.y}
        local v2 = {x = p3.x - p2.x, y = p3.y - p2.y}
        
        local angle = math.atan2(v2.y, v2.x) - math.atan2(v1.y, v1.x)
        table.insert(angles, angle)
    end
    
    return angles
end

-- Helper: Compare angle sequences
function ShapeMatcher:compareAngleSequences(angles1, angles2)
    if #angles1 == 0 and #angles2 == 0 then return 1 end
    if #angles1 == 0 or #angles2 == 0 then return 0 end
    
    local totalDifference = 0
    local comparisons = math.min(#angles1, #angles2)
    
    for i = 1, comparisons do
        local diff = math.abs(angles1[i] - angles2[i])
        diff = math.min(diff, 2 * math.pi - diff) -- Wrap around
        totalDifference = totalDifference + diff
    end
    
    local averageDifference = totalDifference / comparisons
    return math.max(0, 1 - (averageDifference / math.pi))
end

-- Helper: Calculate edge lengths
function ShapeMatcher:calculateEdgeLengths(path)
    if not path or #path < 2 then return {} end
    
    local lengths = {}
    for i = 1, #path - 1 do
        local length = math.sqrt(
            (path[i + 1].x - path[i].x)^2 + 
            (path[i + 1].y - path[i].y)^2
        )
        table.insert(lengths, length)
    end
    
    return lengths
end

-- Helper: Compare edge lengths
function ShapeMatcher:compareEdgeLengths(lengths1, lengths2)
    if #lengths1 == 0 and #lengths2 == 0 then return 1 end
    if #lengths1 == 0 or #lengths2 == 0 then return 0 end
    
    -- Normalize lengths
    local sum1 = 0
    local sum2 = 0
    for _, length in ipairs(lengths1) do sum1 = sum1 + length end
    for _, length in ipairs(lengths2) do sum2 = sum2 + length end
    
    if sum1 == 0 or sum2 == 0 then return 0 end
    
    local totalDifference = 0
    local comparisons = math.min(#lengths1, #lengths2)
    
    for i = 1, comparisons do
        local norm1 = lengths1[i] / sum1
        local norm2 = lengths2[i] / sum2
        totalDifference = totalDifference + math.abs(norm1 - norm2)
    end
    
    local averageDifference = totalDifference / comparisons
    return math.max(0, 1 - averageDifference)
end

-- Apply bonus factors to match result
function ShapeMatcher:applyBonusFactors(result, playerPath, template)
    local bonusMultiplier = 1.0
    
    -- Time bonus (faster = better, but not too fast)
    if playerPath.drawTime then
        local idealTime = 5 + (template.difficulty or 1) * 2 -- 5-15 seconds ideal
        local timeFactor = math.max(0.5, math.min(1.5, idealTime / playerPath.drawTime))
        bonusMultiplier = bonusMultiplier * timeFactor
    end
    
    -- Complexity bonus
    if template.difficulty then
        bonusMultiplier = bonusMultiplier * (1 + template.difficulty * 0.1)
    end
    
    -- Smoothness bonus (fewer points = smoother)
    if playerPath.pointCount and playerPath.pointCount > 10 then
        local smoothnessFactor = math.max(0.8, 1 - (playerPath.pointCount - 10) * 0.01)
        bonusMultiplier = bonusMultiplier * smoothnessFactor
    end
    
    result.bonusMultiplier = bonusMultiplier
    result.finalAccuracy = math.min(1, result.accuracy * bonusMultiplier)
    
    return result
end

-- Set matching method
function ShapeMatcher:setMethod(method)
    if method and table.contains(self.matchMethods, method) then
        self.currentMethod = method
    end
end

-- Get available methods
function ShapeMatcher:getMethods()
    return self.matchMethods
end

-- Helper: Rotate a path by given angle
function ShapeMatcher:rotatePath(path, angle)
    local rotated = {}
    local cosA, sinA = math.cos(angle), math.sin(angle)
    
    for _, point in ipairs(path) do
        table.insert(rotated, {
            x = point.x * cosA - point.y * sinA,
            y = point.x * sinA + point.y * cosA
        })
    end
    
    return rotated
end

-- Helper: Compare two resampled paths point by point
function ShapeMatcher:comparePathVectors(path1, path2)
    if #path1 ~= #path2 or #path1 == 0 then return 0 end
    
    local totalDistance = 0
    for i = 1, #path1 do
        local dx = path1[i].x - path2[i].x
        local dy = path1[i].y - path2[i].y
        totalDistance = totalDistance + math.sqrt(dx * dx + dy * dy)
    end
    
    local averageDistance = totalDistance / #path1
    local maxDistance = math.sqrt(2)  -- Max distance in normalized space
    return math.max(0, 1 - (averageDistance / maxDistance))
end

-- Helper: Check if path has triangle characteristics
function ShapeMatcher:hasTriangleCharacteristics(path)
    if #path < 6 then return false end
    
    local corners = 0
    local totalAngleChange = 0
    
    for i = 2, #path - 1 do
        local p1, p2, p3 = path[i-1], path[i], path[i+1]
        local angle1 = math.atan2(p2.y - p1.y, p2.x - p1.x)
        local angle2 = math.atan2(p3.y - p2.y, p3.x - p2.x)
        local angleDiff = math.abs(angle2 - angle1)
        if angleDiff > math.pi then angleDiff = 2 * math.pi - angleDiff end
        
        totalAngleChange = totalAngleChange + angleDiff
        if angleDiff > 0.5 then corners = corners + 1 end
    end
    
    return corners >= 2 and corners <= 6 and totalAngleChange > 2.5
end

-- Helper: Check if path has square characteristics
function ShapeMatcher:hasSquareCharacteristics(path)
    if #path < 8 then return false end
    
    local corners = 0
    local rightAngles = 0
    
    for i = 2, #path - 1 do
        local p1, p2, p3 = path[i-1], path[i], path[i+1]
        local angle1 = math.atan2(p2.y - p1.y, p2.x - p1.x)
        local angle2 = math.atan2(p3.y - p2.y, p3.x - p2.x)
        local angleDiff = math.abs(angle2 - angle1)
        if angleDiff > math.pi then angleDiff = 2 * math.pi - angleDiff end
        
        if angleDiff > 0.5 then
            corners = corners + 1
            if math.abs(angleDiff - math.pi/2) < 0.3 then
                rightAngles = rightAngles + 1
            end
        end
    end
    
    return corners >= 3 and corners <= 8 and rightAngles >= 2
end

-- Helper: Check if path has circle characteristics
function ShapeMatcher:hasCircleCharacteristics(path)
    if #path < 8 then return false end
    
    local totalAngleChange = 0
    local maxAngleDiff = 0
    
    for i = 2, #path - 1 do
        local p1, p2, p3 = path[i-1], path[i], path[i+1]
        local angle1 = math.atan2(p2.y - p1.y, p2.x - p1.x)
        local angle2 = math.atan2(p3.y - p2.y, p3.x - p2.x)
        local angleDiff = math.abs(angle2 - angle1)
        if angleDiff > math.pi then angleDiff = 2 * math.pi - angleDiff end
        
        totalAngleChange = totalAngleChange + angleDiff
        maxAngleDiff = math.max(maxAngleDiff, angleDiff)
    end
    
    -- Circles should have smooth curves (many small angle changes, no big corners)
    return totalAngleChange > 3.0 and maxAngleDiff < 1.0
end

return ShapeMatcher
