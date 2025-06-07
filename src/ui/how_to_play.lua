local HowToPlay = {}
local Gamestate = require 'hump.gamestate'

function HowToPlay:draw()
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0.1,0.1,0.15,0.98)
    love.graphics.rectangle('fill', 0, 0, ww, wh)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.printf("How to Play", 0, 40, ww, 'center')
    love.graphics.setFont(love.graphics.newFont(18))
    local y = 110
    local lines = {
        "1. Move with arrow keys.",
        "2. Draw a trail by leaving the border.",
        "3. Close a loop to claim territory.",
        "4. Avoid enemies and don't let them touch your trail!",
        "5. Use your character's special ability (SPACE) when ready.",
        "6. Each character and stage has unique rules.",
        "7. Claim enough of the grid to win the stage.",
        "8. Try to finish the run with every character!",
        "",
        "Press ESC to return to the menu."
    }
    for i, line in ipairs(lines) do
        love.graphics.printf(line, 0, y + (i-1)*32, ww, 'center')
    end
end

function HowToPlay:keypressed(key)
    if key == 'escape' then
        local Menu = require 'src.ui.menu'
        Gamestate.switch(Menu)
    end
end

return HowToPlay
