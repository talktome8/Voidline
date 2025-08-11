-- src/ui/ui_manager.lua
-- Centralized UI management system with proper layering and responsive design

local Config = require 'src.config'
local UIManager = {}

-- UI Layer system for proper z-indexing
UIManager.Layer = {
    BACKGROUND = 1,
    GAME = 2,
    HUD = 3,
    MENU = 4,
    OVERLAY = 5,
    MODAL = 6,
    TOOLTIP = 7
}

-- Initialize UI Manager
function UIManager:init()
    self.layers = {}
    self.activeMenus = {}
    self.transitions = {}
    self.fonts = {}
    self.modalStack = {}
    self.isResponsive = true
    
    -- Initialize layers
    for _, layer in pairs(self.Layer) do
        self.layers[layer] = {}
    end
    
    -- Load responsive fonts
    self:loadFonts()
    
    -- Input handling
    self.inputBuffer = {}
    self.lastInput = 0
    self.inputDelay = 0.2 -- Prevent input spam
end

-- Load fonts with responsive sizing
function UIManager:loadFonts()
    local baseSizes = {
        title = 36,
        heading = 24,
        body = 16,
        small = 12,
        tiny = 10
    }
    
    for name, size in pairs(baseSizes) do
        local scaledSize = Config:getFontSize(size)
        self.fonts[name] = love.graphics.newFont(scaledSize)
    end
end

-- Add element to specific layer
function UIManager:addElement(layer, element)
    if not self.layers[layer] then
        error("Invalid UI layer: " .. tostring(layer))
    end
    
    element.layer = layer
    element.id = element.id or (#self.layers[layer] + 1)
    element.visible = element.visible ~= false -- Default to visible
    element.active = element.active ~= false   -- Default to active
    
    table.insert(self.layers[layer], element)
    return element
end

-- Remove element from its layer
function UIManager:removeElement(element)
    if not element.layer then return false end
    
    local layer = self.layers[element.layer]
    for i, el in ipairs(layer) do
        if el == element then
            table.remove(layer, i)
            return true
        end
    end
    return false
end

-- Clear specific layer
function UIManager:clearLayer(layer)
    if self.layers[layer] then
        self.layers[layer] = {}
    end
end

-- Show menu with proper stacking
function UIManager:showMenu(menuName, menuData)
    -- Close existing menus of the same type
    self:hideMenu(menuName)
    
    local menu = {
        name = menuName,
        data = menuData,
        visible = true,
        fadeAlpha = 0,
        targetAlpha = 1,
        fadeSpeed = 1 / Config.ui.menuFadeTime
    }
    
    self.activeMenus[menuName] = menu
    self:addElement(self.Layer.MENU, menu)
    
    return menu
end

-- Hide menu with fade transition
function UIManager:hideMenu(menuName)
    local menu = self.activeMenus[menuName]
    if menu then
        menu.targetAlpha = 0
        menu.closing = true
    end
end

-- Show modal dialog
function UIManager:showModal(modalData)
    modalData.layer = self.Layer.MODAL
    modalData.fadeAlpha = 0
    modalData.targetAlpha = 1
    modalData.fadeSpeed = 2.0
    
    table.insert(self.modalStack, modalData)
    self:addElement(self.Layer.MODAL, modalData)
    
    return modalData
end

-- Close top modal
function UIManager:closeModal()
    if #self.modalStack > 0 then
        local modal = table.remove(self.modalStack)
        self:removeElement(modal)
    end
end

-- Update UI system
function UIManager:update(dt)
    -- Update transitions and animations
    for layer, elements in pairs(self.layers) do
        for i = #elements, 1, -1 do
            local element = elements[i]
            
            -- Handle fade transitions
            if element.fadeAlpha and element.targetAlpha then
                local fadeSpeed = element.fadeSpeed or 3.0
                local diff = element.targetAlpha - element.fadeAlpha
                
                if math.abs(diff) > 0.01 then
                    element.fadeAlpha = element.fadeAlpha + diff * fadeSpeed * dt
                else
                    element.fadeAlpha = element.targetAlpha
                    
                    -- Remove elements that have faded out
                    if element.closing and element.fadeAlpha <= 0 then
                        table.remove(elements, i)
                        if element.name and self.activeMenus[element.name] then
                            self.activeMenus[element.name] = nil
                        end
                    end
                end
            end
            
            -- Update element-specific logic
            if element.update then
                element:update(dt)
            end
        end
    end
    
    -- Handle input delays
    self.lastInput = self.lastInput + dt
end

-- Draw all UI elements in layer order
function UIManager:draw()
    -- Draw layers in order
    for layer = 1, #self.Layer do
        if self.layers[layer] then
            for _, element in ipairs(self.layers[layer]) do
                if element.visible and element.draw then
                    -- Apply fade alpha if present
                    if element.fadeAlpha then
                        local r, g, b, a = love.graphics.getColor()
                        love.graphics.setColor(r, g, b, a * element.fadeAlpha)
                        element:draw()
                        love.graphics.setColor(r, g, b, a)
                    else
                        element:draw()
                    end
                end
            end
        end
    end
end

-- Create button with responsive design
function UIManager:createButton(text, x, y, width, height, callback)
    local button = {
        text = text,
        x = x or 0,
        y = y or 0,
        width = width or 200,
        height = height or Config.ui.buttonHeight,
        callback = callback,
        hovered = false,
        pressed = false,
        enabled = true,
        
        draw = function(self)
            local color = Config.ui.colors.primary
            if not self.enabled then
                color = {0.5, 0.5, 0.5, 1.0}
            elseif self.pressed then
                color = {color[1] * 0.8, color[2] * 0.8, color[3] * 0.8, color[4]}
            elseif self.hovered then
                color = {color[1] * 1.2, color[2] * 1.2, color[3] * 1.2, color[4]}
            end
            
            -- Draw button background
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 5, 5)
            
            -- Draw button border
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 5, 5)
            
            -- Draw button text
            love.graphics.setFont(UIManager.fonts.body)
            local textWidth = UIManager.fonts.body:getWidth(self.text)
            local textHeight = UIManager.fonts.body:getHeight()
            local textX = self.x + (self.width - textWidth) / 2
            local textY = self.y + (self.height - textHeight) / 2
            
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(self.text, textX, textY)
        end,
        
        update = function(self, dt)
            local mx, my = love.mouse.getPosition()
            self.hovered = mx >= self.x and mx <= self.x + self.width and 
                          my >= self.y and my <= self.y + self.height
        end,
        
        onClick = function(self)
            if self.enabled and self.callback then
                self.callback()
            end
        end
    }
    
    return button
end

-- Create menu with automatic layout
function UIManager:createMenu(title, options, x, y)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Calculate menu dimensions
    local menuWidth = math.min(400, screenWidth * 0.8)
    local buttonHeight = Config.ui.buttonHeight
    local buttonSpacing = Config.ui.buttonSpacing
    local menuHeight = #options * (buttonHeight + buttonSpacing) + 100
    
    -- Center if no position specified
    x = x or (screenWidth - menuWidth) / 2
    y = y or (screenHeight - menuHeight) / 2
    
    local menu = {
        title = title,
        x = x,
        y = y,
        width = menuWidth,
        height = menuHeight,
        options = {},
        selectedIndex = 1,
        
        draw = function(self)
            -- Draw menu background
            love.graphics.setColor(Config.ui.colors.background)
            love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 10, 10)
            
            -- Draw menu border
            love.graphics.setColor(Config.ui.colors.primary)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 10, 10)
            
            -- Draw title
            if self.title then
                love.graphics.setFont(UIManager.fonts.title)
                local titleWidth = UIManager.fonts.title:getWidth(self.title)
                local titleX = self.x + (self.width - titleWidth) / 2
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(self.title, titleX, self.y + 20)
            end
            
            -- Draw options
            for i, option in ipairs(self.options) do
                option:draw()
            end
        end,
        
        update = function(self, dt)
            for _, option in ipairs(self.options) do
                option:update(dt)
            end
        end
    }
    
    -- Create buttons for options
    local startY = y + 80
    for i, option in ipairs(options) do
        local buttonY = startY + (i - 1) * (buttonHeight + buttonSpacing)
        local button = UIManager:createButton(
            option.text,
            x + 20,
            buttonY,
            menuWidth - 40,
            buttonHeight,
            option.callback
        )
        
        table.insert(menu.options, button)
    end
    
    return menu
end

-- Handle input for UI elements
function UIManager:handleInput(key, scancode, isRepeat)
    if self.lastInput < self.inputDelay then return end
    
    -- Handle modal input first
    if #self.modalStack > 0 then
        local modal = self.modalStack[#self.modalStack]
        if modal.handleInput then
            modal:handleInput(key, scancode, isRepeat)
            self.lastInput = 0
            return
        end
    end
    
    -- Handle menu input
    for name, menu in pairs(self.activeMenus) do
        if menu.handleInput then
            menu:handleInput(key, scancode, isRepeat)
            self.lastInput = 0
            return
        end
    end
    
    self.lastInput = 0
end

-- Handle mouse input
function UIManager:handleMouseInput(x, y, button, isTouch, presses)
    -- Check modals first
    if #self.modalStack > 0 then
        local modal = self.modalStack[#self.modalStack]
        if modal.handleMouseInput then
            modal:handleMouseInput(x, y, button, isTouch, presses)
            return
        end
    end
    
    -- Check menu elements
    for layer = #self.Layer, 1, -1 do
        if self.layers[layer] then
            for _, element in ipairs(self.layers[layer]) do
                if element.visible and element.onClick and element.hovered then
                    element:onClick()
                    return
                end
            end
        end
    end
end

-- Responsive layout recalculation
function UIManager:recalculateLayout()
    if not self.isResponsive then return end
    
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Reload fonts with new sizes
    self:loadFonts()
    
    -- Update existing elements
    for layer, elements in pairs(self.layers) do
        for _, element in ipairs(elements) do
            if element.recalculateLayout then
                element:recalculateLayout(screenWidth, screenHeight)
            end
        end
    end
end

-- Cleanup
function UIManager:cleanup()
    for layer, elements in pairs(self.layers) do
        for _, element in ipairs(elements) do
            if element.cleanup then
                element:cleanup()
            end
        end
    end
    
    self.layers = {}
    self.activeMenus = {}
    self.modalStack = {}
end

return UIManager
