local SelectCharacter = {}
local Gamestate = require 'hump.gamestate'
local Game = require 'src.game'
local Menu = require 'src.ui.menu'

local font_title, font_char_name, font_char_desc, font_char_passive, font_footer
local input_timer = 0
local input_delay = 0.18

function SelectCharacter:load()
    local charactersModule = require('src.characters.init')
    self.characters = {}
    for k, v in pairs(charactersModule) do
        if type(v) == "table" and v.name then
            table.insert(self.characters, v)
        end
    end
    self.selectedIdx = 1
    font_title = love.graphics.newFont(28)
    font_char_name = love.graphics.newFont(20)
    font_char_desc = love.graphics.newFont(14)
    font_char_passive = love.graphics.newFont(12)
    font_footer = love.graphics.newFont(16)
end

function SelectCharacter:enter()
    self:load()
end

function SelectCharacter:update(dt)
    input_timer = math.max(0, input_timer - dt)
    if input_timer > 0 then return end
end

function SelectCharacter:keypressed(key)
    if key == 'down' then
        self.selectedIdx = math.min(self.selectedIdx + 1, #self.characters)
    elseif key == 'up' then
        self.selectedIdx = math.max(self.selectedIdx - 1, 1)
    elseif key == 'escape' then
        Gamestate.switch(Menu)
    elseif key == 'return' or key == 'kpenter' or key == 'space' then
        local char = self.characters[self.selectedIdx]
        if char then
            Gamestate.switch(Game, char)
        end
    end
end

function SelectCharacter:draw()
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    -- Modern animated gradient background
    for i=0, wh, 2 do
        local t = i/wh
        love.graphics.setColor(0.10*(1-t)+0.18*t, 0.15*(1-t)+0.22*t, 0.22*(1-t)+0.32*t + 0.03*math.sin(love.timer.getTime()*0.7+i*0.01), 1)
        love.graphics.rectangle('fill', 0, i, ww, 2)
        if i%18==0 then
            love.graphics.setColor(0.12,0.18,0.28,0.10+0.08*math.abs(math.sin(love.timer.getTime()*0.5+i*0.02)))
            for x=0,ww,40 do
                love.graphics.circle('fill', x, i, 8+2*math.sin(love.timer.getTime()+x*0.01+i*0.01))
            end
        end
    end
    -- Title with animated shadow
    love.graphics.setFont(font_title)
    for dx=-2,2 do for dy=-2,2 do
        if dx~=0 or dy~=0 then
            love.graphics.setColor(0,0,0,0.18-0.02*math.abs(dx*dy))
            love.graphics.printf('Welcome to Voidline!', 2+dx, 42+dy, ww, 'center')
        end
    end end
    love.graphics.setColor(1,1,1)
    love.graphics.printf('Welcome to Voidline!', 2, 42, ww, 'center')
    -- Add animated character icon
    local charPulse = 0.9+0.1*math.sin(love.timer.getTime()*2.2)
    love.graphics.setColor(0.2*charPulse,0.7*charPulse,1*charPulse,0.7)
    love.graphics.circle('fill', ww/2, 120, 28+4*charPulse, 48)
    love.graphics.setColor(1,1,1,0.18)
    love.graphics.circle('line', ww/2, 120, 32+5*charPulse, 48)
    love.graphics.setFont(font_char_desc)
    love.graphics.setColor(0.8,0.9,1,0.92)
    love.graphics.printf('Choose your character to begin your journey. Each one has unique abilities and playstyle!', 0, 80, ww, 'center')
    love.graphics.setFont(font_title)
    love.graphics.setColor(1,1,1)
    love.graphics.printf('Character Selection', 0, 130, ww, 'center')
    local startY = 180
    for i, char in ipairs(self.characters) do
        local y = startY + (i-1) * 90
        local isSelected = (i == self.selectedIdx)
        local bgColor = char.color or {0.7,0.7,0.7}
        -- Card shadow
        if isSelected then
            love.graphics.setColor(0,0,0,0.18)
            love.graphics.rectangle('fill', ww/2-184, y-14, 368, 88, 22, 22)
        end
        -- Card background with animated border
        if isSelected then
            local pulse = 0.95+0.05*math.sin(love.timer.getTime()*3)
            love.graphics.setColor(bgColor[1]*pulse, bgColor[2]*pulse, bgColor[3]*pulse, 0.22+0.08*pulse)
            love.graphics.rectangle('fill', ww/2-180, y-10, 360, 80, 18, 18)
            love.graphics.setColor(1, 0.85, 0.2, 0.9)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle('line', ww/2-180, y-10, 360, 80, 18, 18)
            love.graphics.setLineWidth(1)
        else
            love.graphics.setColor(bgColor[1]*0.5, bgColor[2]*0.5, bgColor[3]*0.5, 0.7)
            love.graphics.rectangle('fill', ww/2-180, y-10, 360, 80, 18, 18)
        end
        -- Character name
        love.graphics.setFont(font_char_name)
        love.graphics.setColor(1,1,1)
        love.graphics.printf(char.name, ww/2-170, y, 340, 'left')
        -- Character description
        love.graphics.setFont(font_char_desc)
        love.graphics.setColor(0.8,0.9,1,0.92)
        love.graphics.printf(char.description or '', ww/2-170, y+24, 340, 'left')
        -- Character passives
        love.graphics.setFont(font_char_passive)
        love.graphics.setColor(0.2,0.7,1,1)
        if char.passives then
            for pi, passive in ipairs(char.passives) do
                love.graphics.printf(passive, ww/2-170, y+44+pi*14, 340, 'left')
            end
        end
    end
    -- Footer
    love.graphics.setFont(font_footer)
    love.graphics.setColor(0.7,0.9,1,0.7)
    love.graphics.printf('Use ↑/↓ to select, Enter/Space to confirm, Esc to return', 0, wh-60, ww, 'center')
    love.graphics.setColor(0.8,0.9,1,0.7)
    love.graphics.printf('Each character has unique abilities! Try to unlock them all.', 0, wh-36, ww, 'center')
end

return SelectCharacter
