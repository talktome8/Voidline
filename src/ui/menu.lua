-- Menu State for Voidline
local Gamestate = require 'hump.gamestate'

local Menu = {}

-- Fallback menu system
local fallbackButtons = {}
local font = nil
local titleFont = nil

function Menu:enter()
    local ok, Config = pcall(require, 'src.config')
    if ok and Config.debug and Config.debug.enabled then print("Menu:enter() called") end
    
    -- Initialize fonts with fallbacks
    titleFont = love.graphics.newFont(32) or love.graphics.getFont()
    font = love.graphics.newFont(16) or love.graphics.getFont()
    
    -- Initialize particles for background effect
    self.backgroundTime = 0
    self.particles = {}
    
    -- Generate some background particles
    for i = 1, 50 do
        table.insert(self.particles, {
            x = math.random(0, love.graphics.getWidth()),
            y = math.random(0, love.graphics.getHeight()),
            speed = math.random(10, 50),
            size = math.random(1, 3),
            alpha = math.random(0.1, 0.5)
        })
    end
    
    self:initializeFallbackMenu()
    if ok and Config.debug and Config.debug.enabled then print("Menu initialized successfully") end
end

function Menu:initializeFallbackMenu()
    local ok, Config = pcall(require, 'src.config')
    if ok and Config.debug and Config.debug.enabled then print("Initializing fallback menu") end
    
    -- Create simple fallback buttons
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local buttonWidth = 300
    local buttonHeight = 50
    local startX = (screenWidth - buttonWidth) / 2
    local startY = screenHeight / 2
    
    fallbackButtons = {
        {
            text = "Start Game",
            x = startX,
            y = startY,
            width = buttonWidth,
            height = buttonHeight,
            hovered = false,
            callback = function()
                if ok and Config.debug and Config.debug.enabled then print("Starting game...") end
                local success, Game = pcall(require, 'src.game')
                if success and Game then
                    Gamestate.switch(Game)
                else
                    if ok and Config.debug and Config.debug.enabled then print("Failed to load game! Error: " .. tostring(Game)) end
                end
            end
        },
        {
            text = "How to Play",
            x = startX,
            y = startY + 70,
            width = buttonWidth,
            height = buttonHeight,
            hovered = false,
            callback = function()
                if ok and Config.debug and Config.debug.enabled then print("How to Play clicked") end
                -- Could load a how-to-play state later
            end
        },
        {
            text = "Settings",
            x = startX,
            y = startY + 140,
            width = buttonWidth,
            height = buttonHeight,
            hovered = false,
            callback = function()
                if ok and Config.debug and Config.debug.enabled then print("Settings clicked (not implemented)") end
            end
        },
        {
            text = "Quit",
            x = startX,
            y = startY + 210,
            width = buttonWidth,
            height = buttonHeight,
            hovered = false,
            callback = function()
                love.event.quit()
            end
        }
    }
    
    if ok and Config.debug and Config.debug.enabled then print("Created " .. #fallbackButtons .. " fallback buttons") end
end

function Menu:update(dt)
    -- Update background animation
    self.backgroundTime = self.backgroundTime + dt
    
    -- Update particles
    for _, particle in ipairs(self.particles) do
        particle.y = particle.y + particle.speed * dt
        if particle.y > love.graphics.getHeight() then
            particle.y = -10
            particle.x = math.random(0, love.graphics.getWidth())
        end
    end
    
    -- Update button hover states
    local mx, my = love.mouse.getPosition()
    for _, button in ipairs(fallbackButtons) do
        button.hovered = mx >= button.x and mx <= button.x + button.width and
                        my >= button.y and my <= button.y + button.height
    end
end

function Menu:draw()
    -- Clear screen with dark background
    love.graphics.clear(0.05, 0.05, 0.1, 1)
    
    -- Draw animated background particles
    love.graphics.setColor(0.3, 0.8, 1.0, 0.3)
    for _, particle in ipairs(self.particles) do
        love.graphics.circle("fill", particle.x, particle.y, particle.size)
    end
    
    -- Draw animated background grid effect
    love.graphics.setColor(0.1, 0.3, 0.6, 0.2)
    local time = self.backgroundTime
    for i = 1, 5 do
        local offset = math.sin(time + i) * 20
        love.graphics.line(0, i * 120 + offset, love.graphics.getWidth(), i * 120 + offset)
        love.graphics.line(i * 160 + offset, 0, i * 160 + offset, love.graphics.getHeight())
    end
    
    -- Draw title with glow effect
    local titleText = "VOIDLINE"
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Title glow effect
    for i = 5, 1, -1 do
        love.graphics.setColor(0.3, 0.8, 1.0, 0.3 / i)
        love.graphics.setFont(titleFont)
        love.graphics.printf(titleText, -i, screenHeight / 6 - i, screenWidth, "center")
        love.graphics.printf(titleText, i, screenHeight / 6 + i, screenWidth, "center")
    end
    
    -- Main title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(titleFont)
    love.graphics.printf(titleText, 0, screenHeight / 6, screenWidth, "center")
    
    -- Subtitle
    love.graphics.setFont(font)
    local subtitleText = "Enter the Void"
    love.graphics.setColor(0.7, 0.9, 1.0, 0.8)
    love.graphics.printf(subtitleText, 0, screenHeight / 6 + 50, screenWidth, "center")
    
    -- Draw fallback buttons
    self:drawFallbackButtons()
end

function Menu:drawFallbackButtons()
    love.graphics.setFont(font)
    
    for _, button in ipairs(fallbackButtons) do
        -- Button background
        if button.hovered then
            love.graphics.setColor(0.2, 0.5, 0.8, 0.8)
        else
            love.graphics.setColor(0.1, 0.1, 0.2, 0.7)
        end
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 5, 5)
        
        -- Button border
        if button.hovered then
            love.graphics.setColor(0.5, 0.8, 1.0, 1)
        else
            love.graphics.setColor(0.3, 0.6, 0.9, 0.8)
        end
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 5, 5)
        
    -- Button text
    love.graphics.setColor(1, 1, 1, 1)
    local fhObj = love.graphics.getFont()
    local fheight = (fhObj and fhObj.getHeight) and fhObj:getHeight() or 16
    love.graphics.printf(button.text, button.x, button.y + button.height/2 - fheight/2, button.width, "center")
    end
end

function Menu:keypressed(key, scancode, isRepeat)
    if key == "escape" then
        love.event.quit()
    elseif key == "return" or key == "space" then
        -- Activate first button (Start Game)
        if fallbackButtons[1] and fallbackButtons[1].callback then
            fallbackButtons[1].callback()
        end
    end
end

function Menu:mousepressed(x, y, button, isTouch, presses)
    if button == 1 then -- Left mouse button
        for _, btn in ipairs(fallbackButtons) do
            if x >= btn.x and x <= btn.x + btn.width and
               y >= btn.y and y <= btn.y + btn.height then
                local ok, Config = pcall(require, 'src.config')
                if ok and Config.debug and Config.debug.enabled then print("Button clicked: " .. btn.text) end
                if btn.callback then
                    btn.callback()
                end
                break
            end
        end
    end
end

function Menu:resize(w, h)
    -- Reinitialize buttons with new screen dimensions
    self:initializeFallbackMenu()
end

function Menu:leave()
    local ok, Config = pcall(require, 'src.config')
    if ok and Config.debug and Config.debug.enabled then print("Menu:leave() called") end
    -- Clean up
    fallbackButtons = {}
    self.particles = {}
end

return Menu
