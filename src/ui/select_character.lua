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
    -- רקע הדרגתי חלק
    for i=0, wh, 2 do
        local t = i/wh
        love.graphics.setColor(0.13*(1-t)+0.18*t, 0.16*(1-t)+0.22*t, 0.22*(1-t)+0.28*t, 1)
        love.graphics.rectangle('fill', 0, i, ww, 2)
    end
    -- כותרת עם צל
    love.graphics.setFont(font_title)
    love.graphics.setColor(0,0,0,0.22)
    love.graphics.printf('Welcome to Voidline!', 2, 42, ww, 'center')
    love.graphics.setColor(1,1,1)
    love.graphics.printf('Welcome to Voidline!', 0, 40, ww, 'center')
    love.graphics.setFont(font_char_desc)
    love.graphics.setColor(0.8,0.9,1,0.85)
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
            love.graphics.setColor(0,0,0,0.22)
            love.graphics.rectangle('fill', ww/2-184, y-14, 368, 88, 18, 18)
        end
        -- Card background
        if isSelected then
            love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], 0.28)
            love.graphics.rectangle('fill', ww/2-180, y-10, 360, 80, 16, 16)
            love.graphics.setColor(1, 0.85, 0.2, 0.95)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle('line', ww/2-180, y-10, 360, 80, 16, 16)
            love.graphics.setLineWidth(1)
        else
            love.graphics.setColor(bgColor[1]*0.4, bgColor[2]*0.4, bgColor[3]*0.4, 0.5)
            love.graphics.rectangle('fill', ww/2-180, y-10, 360, 80, 16, 16)
        end
        -- Character icon
        love.graphics.setColor(bgColor)
        love.graphics.circle('fill', ww/2-150, y+30, 24)
        -- Name
        love.graphics.setColor(0.1,0.1,0.1)
        love.graphics.setFont(font_char_name)
        love.graphics.print(char.name, ww/2-110, y+8)
        -- Description
        love.graphics.setFont(font_char_desc)
        love.graphics.setColor(0.22,0.22,0.22)
        love.graphics.printf(char.description, ww/2-110, y+38, 260, 'left')
        -- Passives/abilities
        love.graphics.setFont(font_char_passive)
        love.graphics.setColor(0.18,0.18,0.18)
        if char.passives then
            for pi, passive in ipairs(char.passives) do
                love.graphics.print(passive, ww/2+80, y+8+(pi-1)*16)
            end
        end
        -- If selected, show extra highlight and ability/cooldown
        if isSelected then
            love.graphics.setColor(1,1,1,0.95)
            love.graphics.setFont(font_char_passive)
            if char.activeAbilityName then
                love.graphics.printf('Active: '..char.activeAbilityName, ww/2-110, y+62, 260, 'left')
            end
            if char.activeAbilityDesc then
                love.graphics.setColor(0.2,0.2,0.2,0.8)
                love.graphics.printf(char.activeAbilityDesc, ww/2-110, y+78, 260, 'left')
            end
        end
    end
    love.graphics.setFont(font_footer)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Navigate with ↑/↓, select with ENTER, back with ESC", 0, wh - 60, ww, 'center')
end

return SelectCharacter
