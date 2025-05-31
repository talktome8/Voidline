local SelectCharacter = {}
local characters = require('src.characters.init')
local selected = 1
local Gamestate = require 'hump.gamestate' 
local Game = require 'src.game' 

local input_delay = 0.15
local input_timer = 0

-- Fonts
local font_title
local font_char_name
local font_char_desc
local font_char_passive
local font_footer

function SelectCharacter:load()
    selected = 1
    input_timer = 0 -- Reset input timer on load

    -- Load fonts
    font_title = love.graphics.newFont(24)
    font_char_name = love.graphics.newFont(18)
    font_char_desc = love.graphics.newFont(13)
    font_char_passive = love.graphics.newFont(11)
    font_footer = love.graphics.newFont(18)
    print("SelectCharacter:load() - Fonts loaded") -- Debug print
end

-- Add an enter function to ensure fonts are loaded when the state is entered
function SelectCharacter:enter(...)
    print("SelectCharacter:enter() called") -- Debug print
    self:load()
    -- Forward any arguments passed during Gamestate.switch if needed by other logic in enter
    -- For now, just calling load is the primary concern.
end

function SelectCharacter:update(dt)
    input_timer = math.max(0, input_timer - dt) -- Decrement input timer

    if input_timer == 0 then
        -- Handle input for character selection
        if love.keyboard.isDown('right') then
            selected = math.min(selected + 1, #characters)
            input_timer = input_delay
        elseif love.keyboard.isDown('left') then
            selected = math.max(selected - 1, 1)
            input_timer = input_delay
        elseif love.keyboard.isDown('escape') then -- Added escape key for back
            local Menu = require 'src.ui.menu' -- Require Menu only when needed
            Gamestate.switch(Menu) 
            input_timer = input_delay
        end

        if love.keyboard.isDown('return') or love.keyboard.isDown('space') then
            Game:selectCharacter(characters[selected]) -- Pass the actual character object
            -- Gamestate.switch(Game) -- Switching to Game will be handled by select_realm or directly if no realm selection
            local SelectRealm = require 'src.ui.select_realm' -- Require select_realm here
            Gamestate.switch(SelectRealm) -- Switch to realm selection screen
            input_timer = input_delay
        end
    end
end

function SelectCharacter:draw()
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setFont(font_title)
    love.graphics.printf('Select Character', 0, 40, ww, 'center')
    for i, char in ipairs(characters) do
        local y = 120 + (i-1)*120
        if i == selected then
            love.graphics.setColor(1,1,0.4,1)
        else
            love.graphics.setColor(char.color[1], char.color[2], char.color[3], 0.7)
        end
        love.graphics.rectangle('fill', ww/2-180, y, 360, 100, 16, 16)
        love.graphics.setColor(char.color)
        love.graphics.circle('fill', ww/2-150, y+50, 30)
        love.graphics.setColor(0,0,0,1)
        love.graphics.setFont(font_char_name)
        love.graphics.print(char.name, ww/2-100, y+20)
        love.graphics.setFont(font_char_desc)
        love.graphics.print(char.description, ww/2-100, y+50)
        love.graphics.setFont(font_char_passive)
        for j, passive in ipairs(char.passives or {}) do
            love.graphics.print('- '..passive, ww/2-100, y+70+16*j)
        end
    end
    love.graphics.setColor(1,1,1,1)

    -- Draw Back button hint
    love.graphics.setFont(font_footer)
    love.graphics.printf("Press ESC to go back to Menu", 0, wh - 40, ww, 'center')
end

return SelectCharacter
