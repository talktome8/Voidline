local Menu = {}
local Gamestate = require 'hump.gamestate'
local Game = require 'src.game'
local SelectCharacter = require 'src.ui.select_character' -- Added SelectCharacter require

function Menu:load()
end

function Menu:update(dt)
end

function Menu:draw()
    love.graphics.setColor(1,1,1)
    love.graphics.printf('Voidline', 0, 80, love.graphics.getWidth(), 'center')
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.printf('Press Space/Enter to Start Game', 0, 140, love.graphics.getWidth(), 'center')
    love.graphics.printf('Press C to Select Character', 0, 180, love.graphics.getWidth(), 'center') -- Added option for character select
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.printf('Achievements (P: Personal, G: Global):', 0, 220, love.graphics.getWidth(), 'center') -- Adjusted y-position
    local Achievements = require 'src.ui.achievements'
    Achievements:draw(love.graphics.getWidth()/2-120, 250, 240, 220) -- Adjusted y-position
    love.graphics.setFont(love.graphics.newFont(16))
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
