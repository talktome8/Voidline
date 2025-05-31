local SelectRealm = {}
local Gamestate = require 'hump.gamestate'
local Game = require 'src.game'
local Menu = require 'src.ui.menu' 
local realms = require 'src.realms.init' 

local selected_realm_index = 1
local input_delay = 0.15
local input_timer = 0

function SelectRealm:init()
    -- Ensure realms are loaded, this might be redundant if init.lua handles it well
    if type(realms) == "function" then
        realms = realms() 
    end
    -- Default to first realm if realms table is empty or selected index is out of bounds
    if #realms == 0 then
        print("ERROR: No realms found or loaded for SelectRealm!")
        selected_realm_index = 0 -- Or handle error appropriately
    else
        selected_realm_index = 1
    end
    input_timer = 0
end

function SelectRealm:enter()
    self:init() -- Call init when entering the state
end

function SelectRealm:load() -- HUMP gamestate uses load, but we can call init from it or enter
    self:init()
end

function SelectRealm:update(dt)
    if selected_realm_index == 0 then return end -- Don't update if no realms

    input_timer = math.max(0, input_timer - dt)

    if input_timer == 0 then
        if love.keyboard.isDown('down') then
            selected_realm_index = math.min(selected_realm_index + 1, #realms)
            input_timer = input_delay
        elseif love.keyboard.isDown('up') then
            selected_realm_index = math.max(selected_realm_index - 1, 1)
            input_timer = input_delay
        elseif love.keyboard.isDown('return') or love.keyboard.isDown('space') then
            if realms[selected_realm_index] then
                Game:selectRealm(realms[selected_realm_index])
                if Game.load then Game:load() end -- Ensure game is re-loaded with new realm/character context
                Gamestate.switch(Game)
            else
                print("Error: Selected realm is nil.")
            end
            input_timer = input_delay
        elseif love.keyboard.isDown('escape') then
            local SelectCharacter = require 'src.ui.select_character'
            Gamestate.switch(SelectCharacter) -- Go back to character selection
            input_timer = input_delay
        end
    end
end

function SelectRealm:draw()
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf('Select Realm', 0, 40, ww, 'center')

    if selected_realm_index == 0 or #realms == 0 then
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.printf("No realms available!", 0, wh / 2 - 10, ww, 'center')
        love.graphics.setFont(love.graphics.newFont(18))
        love.graphics.printf("Press ESC to go back", 0, wh - 40, ww, 'center')
        return
    end

    for i, realm in ipairs(realms) do
        local y = 120 + (i - 1) * 100 -- Increased spacing for better readability
        local box_height = 80
        if i == selected_realm_index then
            love.graphics.setColor(1, 1, 0.4, 1) 
        else
            love.graphics.setColor(0.7, 0.7, 0.7, 0.7) 
        end
        love.graphics.rectangle('fill', ww / 2 - 200, y, 400, box_height, 10, 10)

        love.graphics.setColor(0, 0, 0, 1) 
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.printf(realm.name or "Unnamed Realm", ww / 2 - 190, y + 15, 380, 'left')
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.printf(realm.description or "No description available.", ww / 2 - 190, y + 45, 380, 'left')
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.printf("Press ESC to go back to Character Select", 0, wh - 40, ww, 'center')
end

return SelectRealm
