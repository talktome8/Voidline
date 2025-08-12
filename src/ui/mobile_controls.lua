-- src/ui/mobile_controls.lua
-- Touch-friendly mobile controls overlay

local MobileControls = {}

function MobileControls:init()
    self.enabled = false
    self.buttonSize = 60
    self.buttonSpacing = 10
    self.opacity = 0.7
    
    -- Detect if we're on a mobile platform
    self:detectMobile()
    
    -- Virtual D-pad buttons
    self.buttons = {
        up = { x = 0, y = 0, pressed = false },
        down = { x = 0, y = 0, pressed = false },
        left = { x = 0, y = 0, pressed = false },
        right = { x = 0, y = 0, pressed = false },
        ability = { x = 0, y = 0, pressed = false } -- For character abilities
    }
    
    self:calculateButtonPositions()
end

function MobileControls:detectMobile()
    -- Enable mobile controls if touch is available or on mobile platforms
    if love.touch then
        self.enabled = true
    end
    
    -- Could also check for specific mobile platforms
    local os = love.system.getOS()
    if os == "Android" or os == "iOS" then
        self.enabled = true
    end
end

function MobileControls:calculateButtonPositions()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local bottomMargin = 30
    local leftMargin = 30
    local rightMargin = 30
    
    -- Left side D-pad
    local dpadCenterX = leftMargin + self.buttonSize
    local dpadCenterY = screenHeight - bottomMargin - self.buttonSize
    
    self.buttons.left.x = dpadCenterX - self.buttonSize - self.buttonSpacing
    self.buttons.left.y = dpadCenterY
    
    self.buttons.right.x = dpadCenterX + self.buttonSpacing
    self.buttons.right.y = dpadCenterY
    
    self.buttons.up.x = dpadCenterX - self.buttonSize/2
    self.buttons.up.y = dpadCenterY - self.buttonSize - self.buttonSpacing
    
    self.buttons.down.x = dpadCenterX - self.buttonSize/2
    self.buttons.down.y = dpadCenterY + self.buttonSpacing
    
    -- Right side ability button
    self.buttons.ability.x = screenWidth - rightMargin - self.buttonSize
    self.buttons.ability.y = dpadCenterY
end

function MobileControls:update(dt)
    if not self.enabled then return end
    
    -- Reset button states
    for _, button in pairs(self.buttons) do
        button.pressed = false
    end
    
    -- Check touch input
    if love.touch then
        local touches = love.touch.getTouches()
        for _, id in ipairs(touches) do
            local x, y = love.touch.getPosition(id)
            self:checkButtonTouch(x, y)
        end
    end
end

function MobileControls:checkButtonTouch(x, y)
    for name, button in pairs(self.buttons) do
        local dx = x - (button.x + self.buttonSize/2)
        local dy = y - (button.y + self.buttonSize/2)
        local distance = math.sqrt(dx*dx + dy*dy)
        
        if distance <= self.buttonSize/2 + 10 then -- Add some touch tolerance
            button.pressed = true
        end
    end
end

function MobileControls:draw()
    if not self.enabled then return end
    
    -- Draw semi-transparent background for buttons
    love.graphics.push()
    
    for name, button in pairs(self.buttons) do
        local color = button.pressed and {1, 1, 1, self.opacity} or {0.3, 0.3, 0.3, self.opacity}
        love.graphics.setColor(color)
        
        -- Draw circular button
        love.graphics.circle('fill', button.x + self.buttonSize/2, button.y + self.buttonSize/2, self.buttonSize/2, 20)
        
        -- Draw button border
        love.graphics.setColor(0.8, 0.8, 0.8, self.opacity)
        love.graphics.setLineWidth(2)
        love.graphics.circle('line', button.x + self.buttonSize/2, button.y + self.buttonSize/2, self.buttonSize/2, 20)
        
        -- Draw button label
        love.graphics.setColor(1, 1, 1, self.opacity + 0.3)
        local label = ""
        if name == "up" then label = "↑"
        elseif name == "down" then label = "↓"
        elseif name == "left" then label = "←"
        elseif name == "right" then label = "→"
        elseif name == "ability" then label = "E"
        end
        
        local font = love.graphics.getFont()
        local tw = font:getWidth(label)
        local th = font:getHeight()
        love.graphics.print(label, 
            button.x + self.buttonSize/2 - tw/2, 
            button.y + self.buttonSize/2 - th/2)
    end
    
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

-- Get current input state for game logic
function MobileControls:getInput()
    if not self.enabled then return nil end
    
    local input = {
        up = self.buttons.up.pressed,
        down = self.buttons.down.pressed,
        left = self.buttons.left.pressed,
        right = self.buttons.right.pressed,
        ability = self.buttons.ability.pressed
    }
    
    return input
end

function MobileControls:resize()
    if self.enabled then
        self:calculateButtonPositions()
    end
end

return MobileControls
