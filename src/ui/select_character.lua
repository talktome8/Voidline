local SelectCharacter = {}
local characters = require('src.characters.init')
local selected = 1
local Gamestate = require 'hump.gamestate' -- Added Gamestate require
local Game = require 'src.game' -- Added Game require

function SelectCharacter:load()
    selected = 1
end

function SelectCharacter:update(dt)
    -- Handle input for character selection
    if love.keyboard.isDown('right') then
        selected = math.min(selected + 1, #characters)
        love.timer.sleep(0.15) -- Add a small delay to prevent rapid selection
    elseif love.keyboard.isDown('left') then
        selected = math.max(selected - 1, 1)
        love.timer.sleep(0.15) -- Add a small delay to prevent rapid selection
    end

    if love.keyboard.isDown('return') or love.keyboard.isDown('space') then
        Game:selectCharacter(selected) -- Select the character in the Game module
        if Game.load then Game:load() end -- Ensure game is loaded before switching
        Gamestate.switch(Game) -- Switch to the game state
    end
end

function SelectCharacter:draw()
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setFont(love.graphics.newFont(24))
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
        love.graphics.setFont(love.graphics.newFont(18))
        love.graphics.print(char.name, ww/2-100, y+20)
        love.graphics.setFont(love.graphics.newFont(13))
        love.graphics.print(char.description, ww/2-100, y+50)
        love.graphics.setFont(love.graphics.newFont(11))
        for j, passive in ipairs(char.passives or {}) do
            love.graphics.print('- '..passive, ww/2-100, y+70+16*j)
        end
    end
    love.graphics.setColor(1,1,1,1)
end

return SelectCharacter
