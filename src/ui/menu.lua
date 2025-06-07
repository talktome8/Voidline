local love = require "love"
local Menu = {}
local Gamestate = require 'hump.gamestate'
local Achievements = require 'src.ui.achievements'

-- Fonts
local font_title
local font_options
local font_achievements_title
local font_info
local font_menu
local font_tip

function Menu:load()
    font_title = love.graphics.newFont(36)
    font_options = love.graphics.newFont(18)
    font_achievements_title = love.graphics.newFont(14)
    font_info = love.graphics.newFont(16)
    font_menu = love.graphics.newFont(24)
    font_tip = love.graphics.newFont(16)
    self.menuOptions = {
        {label = "Select Character", action = function() Gamestate.switch(require 'src.ui.select_character') end},
        {label = "How to Play", action = function() Gamestate.switch(require 'src.ui.how_to_play') end},
        {label = "Quit", action = function() love.event.quit() end},
    }
end

function Menu:enter()
    self:load()
    self.selectedIdx = 1
end

function Menu:update(dt)
    if love.keyboard.isDown('down') then
        self.selectedIdx = math.min((self.selectedIdx or 1) + 1, #self.menuOptions)
    elseif love.keyboard.isDown('up') then
        self.selectedIdx = math.max((self.selectedIdx or 1) - 1, 1)
    elseif love.keyboard.isDown('return') or love.keyboard.isDown('kpenter') or love.keyboard.isDown('space') then
        local selectedOption = self.menuOptions[self.selectedIdx]
        if selectedOption and selectedOption.action then
            selectedOption.action()
        end
    end
end

function Menu:draw()
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    -- Modern animated gradient background
    for i=0, wh, 2 do
        local t = i/wh
        love.graphics.setColor(0.09*(1-t)+0.18*t, 0.13*(1-t)+0.22*t, 0.19*(1-t)+0.28*t + 0.03*math.sin(love.timer.getTime()*0.7+i*0.01), 1)
        love.graphics.rectangle('fill', 0, i, ww, 2)
        if i%18==0 then
            love.graphics.setColor(0.12,0.18,0.28,0.10+0.08*math.abs(math.sin(love.timer.getTime()*0.5+i*0.02)))
            for x=0,ww,40 do
                love.graphics.circle('fill', x, i, 8+2*math.sin(love.timer.getTime()+x*0.01+i*0.01))
            end
        end
    end
    -- Add animated logo or icon
    local logoPulse = 0.9+0.1*math.sin(love.timer.getTime()*2)
    love.graphics.setColor(0.2*logoPulse,0.7*logoPulse,1*logoPulse,0.7)
    love.graphics.circle('fill', ww/2, 60, 38+6*logoPulse, 64)
    love.graphics.setColor(1,1,1,0.18)
    love.graphics.circle('line', ww/2, 60, 44+8*logoPulse, 64)
    -- Title with animated shadow
    love.graphics.setFont(font_title)
    for dx=-4,4 do for dy=-4,4 do
        if dx~=0 or dy~=0 then
            love.graphics.setColor(0,0,0,0.22-0.02*math.abs(dx*dy))
            love.graphics.printf('Voidline', dx, 80+dy, ww, 'center')
        end
    end end
    love.graphics.setColor(1,1,1)
    love.graphics.printf('Voidline', 0, 80, ww, 'center')
    -- Description
    love.graphics.setFont(font_options)
    love.graphics.setColor(0.8,0.9,1,0.98)
    love.graphics.printf('A tactical arcade game of risk and reward', 0, 128, ww, 'center')
    love.graphics.setColor(0.2,0.7,1,1)
    love.graphics.setFont(font_options)
    love.graphics.printf('Press Space/Enter to Select Character', 0, 160, ww, 'center')
    -- Menu options with highlight and subtle animation
    local menuY = 220
    for i, opt in ipairs(self.menuOptions) do
        local y = menuY + (i-1)*60
        if i == (self.selectedIdx or 1) then
            local pulse = 0.95+0.05*math.sin(love.timer.getTime()*3)
            love.graphics.setColor(0.2*pulse,0.7*pulse,1*pulse,1)
            love.graphics.rectangle('fill', ww/2-140, y-8, 280, 48, 32, 32)
            love.graphics.setColor(1,1,1)
            love.graphics.setFont(font_menu)
            love.graphics.printf(opt.label, 0, y+2, ww, 'center')
        else
            love.graphics.setColor(0.2,0.2,0.2,0.7)
            love.graphics.setFont(font_menu)
            love.graphics.printf(opt.label, 0, y, ww, 'center')
        end
    end
    -- Achievements box with icon
    love.graphics.setFont(font_achievements_title)
    love.graphics.setColor(1,1,1,0.92)
    love.graphics.rectangle('fill', ww/2-160, menuY+140, 320, 120, 18, 18)
    love.graphics.setColor(0.15,0.18,0.22,0.13)
    love.graphics.rectangle('line', ww/2-160, menuY+140, 320, 120, 18, 18)
    love.graphics.setColor(0.2,0.2,0.2,1)
    love.graphics.printf('Achievements', ww/2-160, menuY+148, 320, 'center')
    -- Draw a trophy icon
    love.graphics.setColor(1, 0.85, 0.2, 0.8)
    love.graphics.circle('fill', ww/2, menuY+180, 18, 32)
    love.graphics.setColor(0.7,0.5,0.1,1)
    love.graphics.rectangle('fill', ww/2-8, menuY+198, 16, 12, 4, 4)
    love.graphics.setColor(1,1,1,1)
    Achievements:draw(ww/2-150, menuY+170, 300, 80)
    -- Tip
    love.graphics.setFont(font_tip)
    love.graphics.setColor(0.8,0.9,1,0.7)
    love.graphics.printf("Tip: Claim big areas for more points! Use abilities to outsmart enemies!", 0, wh-60, ww, 'center')
    -- Show controls
    love.graphics.setFont(font_tip)
    love.graphics.setColor(0.7,0.9,1,0.7)
    love.graphics.printf("Controls: Arrows/WASD = Move, Space/Enter = Select, Esc = Quit", 0, wh-36, ww, 'center')
end

function Menu:keypressed(key)
    if key == 'escape' then
        love.event.quit()
    elseif key == 'space' or key == 'return' or key == 'kpenter' then
        local selectedOption = self.menuOptions[self.selectedIdx]
        if selectedOption and selectedOption.action then
            selectedOption.action()
        end
    elseif key == 'down' then
        self.selectedIdx = math.min((self.selectedIdx or 1) + 1, #self.menuOptions)
    elseif key == 'up' then
        self.selectedIdx = math.max((self.selectedIdx or 1) - 1, 1)
    end
end

return Menu
