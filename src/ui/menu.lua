local Menu = {}
local Gamestate = require 'hump.gamestate'
local Game = require 'src.game'

function Menu:load()
end

function Menu:update(dt)
end

function Menu:draw()
    love.graphics.setColor(1,1,1)
    love.graphics.printf('Voidline\nPress Space/Enter to Start', 0, 200, love.graphics.getWidth(), 'center')
end

function Menu:keypressed(key)
    if key == 'space' or key == 'return' then
        if Game and Game.load then Game:load() end
        Gamestate.switch(Game)
    end
end

return Menu
