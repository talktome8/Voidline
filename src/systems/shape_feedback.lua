-- Visual feedback system for shape drawing with color changes and stars

local ShapeFeedback = {}
local ok_cfg, Config = pcall(require, 'src.config')

function ShapeFeedback:init()
    self.isInitialized = true
    
    -- Visual feedback state
    self.shapeState = {
        isCompleted = false,
        successColor = {0.2, 1.0, 0.2, 1.0},  -- Bright green for success
        normalColor = {0.8, 0.8, 1.0, 0.9},   -- Light blue for normal
        currentColor = {0.8, 0.8, 1.0, 0.9},  -- Current display color
        animationTimer = 0,
        glowIntensity = 0
    }
    
    -- Star system for success indication
    self.starSystem = {
        maxStars = 3,
        currentStars = 0,
        starSize = 20,
        starSpacing = 25,
        filledColor = {1.0, 0.9, 0.2, 1.0},   -- Golden yellow for filled stars
        emptyColor = {0.4, 0.4, 0.4, 0.8},    -- Gray for empty stars
        animationScale = 1.0,
        animationTimer = 0
    }
    
    -- Template display settings
    self.templateDisplay = {
        position = {x = 0, y = 0},  -- Will be set based on screen size
        scale = 1.0,
        borderWidth = 3,
        backgroundColor = {0.1, 0.1, 0.2, 0.9},
        borderColor = {0.5, 0.5, 0.8, 1.0}
    }
    
    -- Success animation
    self.successAnimation = {
        active = false,
        timer = 0,
        duration = 1.5,
        pulseIntensity = 0
    }

    -- Cache fonts (avoid recreating every frame)
    local baseSize = 14
    local fontSize = baseSize
    if ok_cfg and Config.getFontSize then
        fontSize = Config:getFontSize(baseSize)
    end
    self.fontSmall = love.graphics.newFont(fontSize)
end

-- Update feedback animations
function ShapeFeedback:update(dt)
    if not self.isInitialized then return end
    
    -- Update color animation
    if self.shapeState.animationTimer > 0 then
        self.shapeState.animationTimer = self.shapeState.animationTimer - dt
        local progress = 1 - (self.shapeState.animationTimer / 0.5) -- 0.5 second animation
        
        if self.shapeState.isCompleted then
            -- Animate to success color
            self.shapeState.currentColor = self:lerpColor(
                self.shapeState.normalColor,
                self.shapeState.successColor,
                progress
            )
            self.shapeState.glowIntensity = math.sin(progress * math.pi) * 0.3
        end
    end
    
    -- Update star animation
    if self.starSystem.animationTimer > 0 then
        self.starSystem.animationTimer = self.starSystem.animationTimer - dt
        local progress = 1 - (self.starSystem.animationTimer / 0.8) -- 0.8 second animation
        self.starSystem.animationScale = 1.0 + math.sin(progress * math.pi) * 0.3
    end
    
    -- Update success animation
    if self.successAnimation.active then
        self.successAnimation.timer = self.successAnimation.timer + dt
        local progress = self.successAnimation.timer / self.successAnimation.duration
        
        if progress >= 1.0 then
            self.successAnimation.active = false
            self.successAnimation.timer = 0
        else
            self.successAnimation.pulseIntensity = math.sin(progress * math.pi * 4) * 0.5
        end
    end
end

-- Set shape completion state with visual feedback
function ShapeFeedback:setShapeCompleted(completed, accuracy)
    if not self.isInitialized then return end
    
    self.shapeState.isCompleted = completed
    
    if completed then
        -- Start color change animation
        self.shapeState.animationTimer = 0.5
        
        -- Calculate stars based on accuracy
        local stars = self:calculateStarsFromAccuracy(accuracy or 0)
        self:setStars(stars)
        
        -- Start success animation
        self.successAnimation.active = true
        self.successAnimation.timer = 0
        
        -- Play simple success sound (if available)
        self:playSuccessSound(stars)
        
        do local ok, Config = pcall(require, 'src.config'); if ok and Config.debug and Config.debug.enabled then
            print("Shape completed! Accuracy:", math.floor((accuracy or 0) * 100) .. "%, Stars:", stars)
        end end
    else
        -- Reset to normal state
        self.shapeState.currentColor = self.shapeState.normalColor
        self.shapeState.glowIntensity = 0
        self:setStars(0)
    end
end

-- Set number of filled stars with animation
function ShapeFeedback:setStars(count)
    if not self.isInitialized then return end
    
    local newCount = math.max(0, math.min(self.starSystem.maxStars, count))
    
    if newCount > self.starSystem.currentStars then
        -- Star gained - animate
        self.starSystem.animationTimer = 0.8
    end
    
    self.starSystem.currentStars = newCount
end

-- Calculate stars based on accuracy percentage
function ShapeFeedback:calculateStarsFromAccuracy(accuracy)
    if accuracy >= 0.95 then return 3      -- 3 stars for 95%+ accuracy
    elseif accuracy >= 0.80 then return 2  -- 2 stars for 80%+ accuracy
    elseif accuracy >= 0.60 then return 1  -- 1 star for 60%+ accuracy
    else return 0 end                       -- No stars below 60%
end

-- Draw the shape template with current feedback state
function ShapeFeedback:drawShapeTemplate(template, x, y, scale)
    if not self.isInitialized or not template or not template.points then return end
    
    scale = scale or 1.0
    local panelWidth = 180 * scale
    local panelHeight = 180 * scale
    
    -- Draw background panel
    love.graphics.setColor(self.templateDisplay.backgroundColor)
    love.graphics.rectangle('fill', x, y, panelWidth, panelHeight, 10, 10)
    
    -- Draw border with current state color
    love.graphics.setColor(self.shapeState.currentColor)
    love.graphics.setLineWidth(self.templateDisplay.borderWidth)
    love.graphics.rectangle('line', x, y, panelWidth, panelHeight, 10, 10)
    
    -- Add glow effect when completed
    if self.shapeState.glowIntensity > 0 then
        love.graphics.setColor(
            self.shapeState.currentColor[1],
            self.shapeState.currentColor[2], 
            self.shapeState.currentColor[3],
            self.shapeState.glowIntensity
        )
        love.graphics.setLineWidth(self.templateDisplay.borderWidth + 4)
        love.graphics.rectangle('line', x - 2, y - 2, panelWidth + 4, panelHeight + 4, 12, 12)
    end
    
    -- Draw the template shape inside the panel
    self:drawTemplateShape(template, x + 20, y + 20, (panelWidth - 40) / 100, scale)
    
    -- Draw shape name
    love.graphics.setColor(1, 1, 1, 1)
    local prevFont = love.graphics.getFont()
    if self.fontSmall then love.graphics.setFont(self.fontSmall) end
    love.graphics.printf(template.name or "Shape", x, y + panelHeight + 5, panelWidth, 'center')
    if prevFont then love.graphics.setFont(prevFont) end
    
    love.graphics.setLineWidth(1) -- Reset line width
end

-- Draw the actual template shape
function ShapeFeedback:drawTemplateShape(template, x, y, scale, overallScale)
    if not template.points or #template.points < 2 then return end
    
    -- Set color based on completion state
    love.graphics.setColor(self.shapeState.currentColor)
    love.graphics.setLineWidth(3 * (overallScale or 1))
    
    -- Determine coordinate format and scale appropriately
    local maxCoordValue = 0
    for _, point in ipairs(template.points) do
        local px = point.x or point.i or 0
        local py = point.y or point.j or 0
        maxCoordValue = math.max(maxCoordValue, px, py)
    end
    
    -- If coordinates are normalized (0-1), scale them up
    local coordinateScale = (maxCoordValue <= 1) and 100 or 1
    
    -- Draw shape outline
    for i = 1, #template.points - 1 do
        local p1 = template.points[i]
        local p2 = template.points[i + 1]
        local x1 = x + (p1.x or p1.i or 0) * coordinateScale * scale
        local y1 = y + (p1.y or p1.j or 0) * coordinateScale * scale
        local x2 = x + (p2.x or p2.i or 0) * coordinateScale * scale
        local y2 = y + (p2.y or p2.j or 0) * coordinateScale * scale
        love.graphics.line(x1, y1, x2, y2)
    end
    
    -- Close the shape if it's marked as closed
    if template.closed and #template.points > 2 then
        local first = template.points[1]
        local last = template.points[#template.points]
        local x1 = x + (first.x or first.i or 0) * coordinateScale * scale
        local y1 = y + (first.y or first.j or 0) * coordinateScale * scale
        local x2 = x + (last.x or last.i or 0) * coordinateScale * scale
        local y2 = y + (last.y or last.j or 0) * coordinateScale * scale
        love.graphics.line(x1, y1, x2, y2)
    end
    
    love.graphics.setLineWidth(1) -- Reset line width
end

-- Draw star indicators above the template
function ShapeFeedback:drawStars(x, y, scale)
    if not self.isInitialized then return end
    
    scale = scale or 1.0
    local starSize = self.starSystem.starSize * scale
    local spacing = self.starSystem.starSpacing * scale
    local totalWidth = (self.starSystem.maxStars - 1) * spacing
    local startX = x + (180 * scale - totalWidth) / 2 -- Center stars above template
    
    for i = 1, self.starSystem.maxStars do
        local starX = startX + (i - 1) * spacing
        local starY = y - starSize - 10
        
        -- Apply animation scale to newly filled stars
        local currentScale = scale
        if i <= self.starSystem.currentStars and self.starSystem.animationTimer > 0 then
            currentScale = currentScale * self.starSystem.animationScale
        end
        
        -- Choose color based on whether star is filled
        if i <= self.starSystem.currentStars then
            love.graphics.setColor(self.starSystem.filledColor)
        else
            love.graphics.setColor(self.starSystem.emptyColor)
        end
        
        -- Draw star shape
        self:drawStar(starX, starY, starSize * currentScale * 0.5, 5)
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

-- Draw a star shape
function ShapeFeedback:drawStar(x, y, radius, points)
    points = points or 5
    local angle = math.pi * 2 / points
    local innerRadius = radius * 0.4
    
    local vertices = {}
    for i = 0, points * 2 - 1 do
        local r = (i % 2 == 0) and radius or innerRadius
        local a = i * angle / 2 - math.pi / 2
        table.insert(vertices, x + math.cos(a) * r)
        table.insert(vertices, y + math.sin(a) * r)
    end
    
    love.graphics.polygon('fill', vertices)
end

-- Linear interpolation between two colors
function ShapeFeedback:lerpColor(color1, color2, t)
    return {
        color1[1] + (color2[1] - color1[1]) * t,
        color1[2] + (color2[2] - color1[2]) * t,
        color1[3] + (color2[3] - color1[3]) * t,
        color1[4] + (color2[4] - color1[4]) * t
    }
end

-- Reset feedback system for new level
function ShapeFeedback:reset()
    if not self.isInitialized then return end
    
    self.shapeState.isCompleted = false
    self.shapeState.currentColor = self.shapeState.normalColor
    self.shapeState.animationTimer = 0
    self.shapeState.glowIntensity = 0
    
    self.starSystem.currentStars = 0
    self.starSystem.animationTimer = 0
    self.starSystem.animationScale = 1.0
    
    self.successAnimation.active = false
    self.successAnimation.timer = 0
end

-- Get current completion state
function ShapeFeedback:isCompleted()
    return self.isInitialized and self.shapeState.isCompleted
end

-- Get current star count
function ShapeFeedback:getStarCount()
    return self.isInitialized and self.starSystem.currentStars or 0
end

-- Play success sound based on star count (simple audio feedback)
function ShapeFeedback:playSuccessSound(stars)
    -- Create simple tone based on star count
    -- Higher stars = higher pitch
    local frequency = 440 + (stars * 110) -- A4 (440Hz) + harmonic intervals
    local duration = 0.2 + (stars * 0.1)  -- Longer sound for more stars
    
    -- Only play if Love2D audio is available
    if love.audio then
        self:generateSuccessBeep(frequency, duration)
    end
end

-- Generate a simple success beep (optional - requires Love2D audio)
function ShapeFeedback:generateSuccessBeep(frequency, duration)
    -- This is a simple implementation - could be enhanced with actual sound files
    local sampleRate = 44100
    local samples = math.floor(sampleRate * duration)
    local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)
    
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local wave = math.sin(2 * math.pi * frequency * t)
        local envelope = math.exp(-t * 3) -- Exponential decay
        soundData:setSample(i, wave * envelope * 0.3) -- Lower volume
    end
    
    local source = love.audio.newSource(soundData)
    source:play()
end

return ShapeFeedback
