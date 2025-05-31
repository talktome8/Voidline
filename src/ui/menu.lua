local Menu = {}
local Gamestate = require 'hump.gamestate'
local Game = require 'src.game'
local SelectCharacter = require 'src.ui.select_character'
local Achievements = require 'src.ui.achievements' -- Moved require to top

-- Fonts
local font_title
local font_options
local font_achievements_title
local font_info

function Menu:load()
    -- Load fonts
    font_title = love.graphics.newFont(36) -- Example: Larger title font
    font_options = love.graphics.newFont(18)
    font_achievements_title = love.graphics.newFont(14)
    font_info = love.graphics.newFont(16)
end

-- Add an enter function to ensure fonts are loaded when the state is entered
function Menu:enter()
    self:load()
end

function Menu:update(dt)
end

function Menu:draw()
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(font_title) -- Use preloaded font
    love.graphics.printf('Voidline', 0, 80, love.graphics.getWidth(), 'center')
    
    love.graphics.setFont(font_options) -- Use preloaded font
    love.graphics.printf('Press Space/Enter to Start Game', 0, 140, love.graphics.getWidth(), 'center')
    love.graphics.printf('Press C to Select Character', 0, 180, love.graphics.getWidth(), 'center')
    
    love.graphics.setFont(font_achievements_title) -- Use preloaded font
    love.graphics.printf('Achievements (P: Personal, G: Global):', 0, 220, love.graphics.getWidth(), 'center')
    
    -- Achievements:draw is called with specific coordinates, assuming it handles its own font settings if needed
    Achievements:draw(love.graphics.getWidth()/2-120, 250, 240, 220)
    
    love.graphics.setFont(font_info) -- Use preloaded font
    love.graphics.setColor(1,1,1)
end

function Menu:keypressed(key)
    if key == 'space' or key == 'return' then
        if Game and Game.load then Game:load() end
        Gamestate.switch(Game)
    elseif key == 'c' then -- Added keybind for character select
        Gamestate.switch(SelectCharacter)
    elseif key == 'escape' then
        love.event.quit()
    end
end

return Menu
