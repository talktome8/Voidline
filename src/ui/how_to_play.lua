local HowToPlay = {}
local Gamestate = require 'hump.gamestate'

local font_title = love.graphics.newFont(32)
local font_menu = love.graphics.newFont(22)
local font_tip = love.graphics.newFont(16)

function HowToPlay:draw()
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0,0,0,0.92)
    love.graphics.rectangle('fill', ww*0.15, wh*0.12, ww*0.7, wh*0.7, 18, 18)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(font_title)
    love.graphics.printf('How to Play', ww*0.15, wh*0.14, ww*0.7, 'center')
    love.graphics.setFont(font_menu)
    love.graphics.setColor(0.8,0.9,1)
    love.graphics.printf('Goal: Claim as much area as possible by closing loops with your trail.\nAvoid enemies and don\'t let them touch your trail!\n\nControls:', ww*0.18, wh*0.22, ww*0.64, 'left')
    love.graphics.setColor(1,1,1)
    love.graphics.printf('Arrow keys - Move\nSpace - Use active ability (if available)\nP - Pause, R - Reset\nESC - Back/Quit', ww*0.18, wh*0.32, ww*0.64, 'left')
    love.graphics.setFont(font_tip)
    love.graphics.setColor(1,0.85,0.2)
    love.graphics.printf('Press ESC to return', ww*0.15, wh*0.78, ww*0.7, 'center')
end

function HowToPlay:update(dt)
    if love.keyboard.isDown('escape') then
        local Menu = require 'src.ui.menu'
        Gamestate.switch(Menu)
    end
end

return HowToPlay
