-- Zone Mirror Ability: Duplicates the last captured area on the opposite side
local ZoneMirror = {}

ZoneMirror.isActive = false
ZoneMirror.cooldown = 35.0  -- 35 second cooldown
ZoneMirror.currentCooldown = 0.0
ZoneMirror.lastCapturedArea = nil  -- Store the last captured area
ZoneMirror.mirrorEffectDuration = 3.0
ZoneMirror.currentEffect = 0.0

function ZoneMirror:load()
    print("Zone Mirror ability loaded")
end

function ZoneMirror:update(dt)
    -- Update cooldown
    if self.currentCooldown > 0 then
        self.currentCooldown = self.currentCooldown - dt
    end
    
    -- Update effect duration
    if self.currentEffect > 0 then
        self.currentEffect = self.currentEffect - dt
        if self.currentEffect <= 0 then
            self.isActive = false
        end
    end
end

function ZoneMirror:canActivate()
    return self.currentCooldown <= 0 and self.lastCapturedArea ~= nil and not self.isActive
end

function ZoneMirror:recordCapturedArea(capturedCells)
    if #capturedCells >= 5 then  -- Only record significant captures
        self.lastCapturedArea = {}
        for _, cell in ipairs(capturedCells) do
            table.insert(self.lastCapturedArea, {i = cell.i, j = cell.j})
        end
        print("📋 Zone Mirror recorded area with", #capturedCells, "cells")
    end
end

function ZoneMirror:activate(player, grid)
    if not self:canActivate() then
        return false
    end
    
    print("🪞 ZONE MIRROR ACTIVATED!")
    
    self.isActive = true
    self.currentCooldown = self.cooldown
    self.currentEffect = self.mirrorEffectDuration
    
    -- Mirror the last captured area
    local mirroredCells = 0
    local gridCenterI = math.floor(grid.width / 2)
    local gridCenterJ = math.floor(grid.height / 2)
    
    for _, cell in ipairs(self.lastCapturedArea) do
        -- Calculate mirrored position (flip across grid center)
        local mirrorI = gridCenterI + (gridCenterI - cell.i)
        local mirrorJ = gridCenterJ + (gridCenterJ - cell.j)
        
        -- Ensure mirrored position is within bounds
        if grid:isInside(mirrorI, mirrorJ) then
            -- Only mirror if cell is not already claimed
            if not grid:isClaimed(mirrorI, mirrorJ) then
                grid.cells[mirrorI][mirrorJ] = 'claimed'
                mirroredCells = mirroredCells + 1
            end
        end
    end
    
    print("Mirrored", mirroredCells, "cells!")
    
    -- Visual effect
    grid._mirrorHighlightTimer = 2.0
    
    return true
end

function ZoneMirror:draw()
    if not self.isActive then return end
    
    -- Draw mirror effect
    local alpha = math.sin(love.timer.getTime() * 6) * 0.3 + 0.5
    love.graphics.setColor(0.2, 0.8, 1.0, alpha * 0.4)
    
    -- Draw connecting lines between original and mirrored areas (if visible)
    if self.lastCapturedArea then
        local grid = _G.Grid or require('src.grid')
        if grid then
            local gridCenterI = math.floor(grid.width / 2)
            local gridCenterJ = math.floor(grid.height / 2)
            
            for _, cell in ipairs(self.lastCapturedArea) do
                local mirrorI = gridCenterI + (gridCenterI - cell.i)
                local mirrorJ = gridCenterJ + (gridCenterJ - cell.j)
                
                if grid:isInside(mirrorI, mirrorJ) and grid:isClaimed(mirrorI, mirrorJ) then
                    local x1, y1 = grid:getNodePixelPosition(cell.i, cell.j)
                    local x2, y2 = grid:getNodePixelPosition(mirrorI, mirrorJ)
                    love.graphics.line(x1, y1, x2, y2)
                end
            end
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function ZoneMirror:drawUI(x, y)
    local available = self:canActivate()
    local hasArea = self.lastCapturedArea ~= nil
    local color
    
    if available then
        color = {0.2, 0.8, 1.0}
    elseif not hasArea then
        color = {0.3, 0.3, 0.5}  -- No area recorded
    else
        color = {0.5, 0.5, 0.5}  -- On cooldown
    end
    
    love.graphics.setColor(color)
    love.graphics.rectangle('fill', x, y, 120, 25, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('line', x, y, 120, 25, 5, 5)
    
    local text
    if available then
        text = "ZONE MIRROR (M)"
    elseif not hasArea then
        text = "Capture area first"
    else
        text = string.format("Cooldown: %.1fs", self.currentCooldown)
    end
    
    love.graphics.printf(text, x + 5, y + 6, 110, 'center')
end

return ZoneMirror
