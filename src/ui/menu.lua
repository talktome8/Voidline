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
    self.menuOptions = {"Select Character", "How to Play", "Quit"}
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
        if self.selectedIdx == 1 then
            local SelectCharacter = require 'src.ui.select_character'
            Gamestate.switch(SelectCharacter)
        elseif self.selectedIdx == 2 then
            local HowToPlay = require 'src.ui.how_to_play'
            Gamestate.switch(HowToPlay)
        elseif self.selectedIdx == 3 then
            love.event.quit()
        end
    end
end

function Menu:draw()
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    -- רקע הדרגתי חלק
    for i=0, wh, 2 do
        local t = i/wh
        love.graphics.setColor(0.07*(1-t)+0.22*t, 0.10*(1-t)+0.28*t, 0.18*(1-t)+0.38*t, 1)
        love.graphics.rectangle('fill', 0, i, ww, 2)
    end

    -- כותרת עם צל עבה
    love.graphics.setFont(font_title)
    for dx=-3,3 do for dy=-3,3 do
        if dx~=0 or dy~=0 then
            love.graphics.setColor(0,0,0,0.22)
            love.graphics.printf('Voidline', dx, 80+dy, ww, 'center')
        end
    end end
    love.graphics.setColor(1,1,1)
    love.graphics.printf('Voidline', 0, 80, ww, 'center')

    -- תיאור
    love.graphics.setFont(font_options)
    love.graphics.setColor(0.7,0.85,1,0.98)
    love.graphics.printf('A tactical arcade game of risk and reward', 0, 128, ww, 'center')
    love.graphics.setColor(0.2,0.7,1,1)
    love.graphics.setFont(font_options)
    love.graphics.printf('Press Space/Enter to Select Character', 0, 160, ww, 'center')

    -- תיבת הישגים
    love.graphics.setFont(font_achievements_title)
    love.graphics.setColor(1,1,1,0.92)
    love.graphics.printf('Achievements (P: Personal, G: Global):', 0, 220, ww, 'center')
    Achievements:draw(ww/2-120, 250, 240, 220)

    -- תפריט אופציות
    love.graphics.setFont(font_menu)
    for i, opt in ipairs(self.menuOptions) do
        local y = 220 + (i-1)*60
        if i == (self.selectedIdx or 1) then
            love.graphics.setColor(0.2,0.7,1,1)
            love.graphics.rectangle('fill', ww/2-140, y-8, 280, 48, 24, 24)
            love.graphics.setColor(1,1,1)
            love.graphics.setFont(font_menu)
            love.graphics.printf(opt, 0, y+2, ww, 'center')
        else
            love.graphics.setColor(0.2,0.2,0.2,0.7)
            love.graphics.setFont(font_menu)
            love.graphics.printf(opt, 0, y, ww, 'center')
        end
    end

    -- טיפ
    love.graphics.setFont(font_tip)
    love.graphics.setColor(0.8,0.9,1,0.7)
    love.graphics.printf("Tip: Claim big areas for more points!", 0, wh-60, ww, 'center')
end

function Menu:keypressed(key)
    if key == 'escape' then
        love.event.quit()
    elseif key == 'space' or key == 'return' or key == 'kpenter' then
        if self.selectedIdx == 1 then
            local SelectCharacter = require 'src.ui.select_character'
            Gamestate.switch(SelectCharacter)
        elseif self.selectedIdx == 2 then
            local HowToPlay = require 'src.ui.how_to_play'
            Gamestate.switch(HowToPlay)
        elseif self.selectedIdx == 3 then
            love.event.quit()
        end
    elseif key == 'down' then
        self.selectedIdx = math.min((self.selectedIdx or 1) + 1, #self.menuOptions)
    elseif key == 'up' then
        self.selectedIdx = math.max((self.selectedIdx or 1) - 1, 1)
    end
end

return Menu
