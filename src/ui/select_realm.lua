local love = require "love" -- Added missing love require
local SelectRealm = {}
local Gamestate = require 'hump.gamestate'
local Game = require 'src.game'
-- local Menu = require 'src.ui.menu' -- Not directly used, can be removed if SelectCharacter handles back navigation

local input_delay = 0.15
local input_timer = 0

-- Fonts
local fontRealmTitle
local fontRealmName
local fontRealmDescription
local fontRealmFooter
local fontLarge = love.graphics.newFont(28)
local fontMedium = love.graphics.newFont(18)
local fontSmall = love.graphics.newFont(13)

local function getCharacterByName(name)
    local characters = require('src.characters.init')
    for _, char in ipairs(characters) do
        if char.name == name then return char end
    end
    return characters[1] -- fallback to first
end

function SelectRealm:init()
    local realms = require('src.realms.init')
    if type(realms) == "function" then
        realms = realms()
    end
    if not realms or type(realms) ~= "table" then
        print("ERROR: realms/init.lua did not return a valid table of realms!")
        realms = {}
    end
    self.realms = realms
    if #self.realms == 0 then
        self.selectedIdx = 0
    else
        self.selectedIdx = 1
    end
    input_timer = 0
    fontRealmTitle = love.graphics.newFont(24)
    fontRealmName = love.graphics.newFont(20)
    fontRealmDescription = love.graphics.newFont(14)
    fontRealmFooter = love.graphics.newFont(18)
end

function SelectRealm:enter()
    self:init()
    self.selectedCharacter = _G.selectedCharacter or nil
    print('DEBUG: SelectRealm:enter - selectedCharacter from _G:', self.selectedCharacter and self.selectedCharacter.name or 'NIL', tostring(self.selectedCharacter))
    if self.selectedCharacter then
        local Game = require 'src.game'
        Game:selectCharacter(self.selectedCharacter)
        print('DEBUG: SelectRealm:enter - _G.selectedCharacter:', _G.selectedCharacter and _G.selectedCharacter.name or 'NIL', tostring(_G.selectedCharacter))
    end
end

function SelectRealm:load()
    self:init()
end

function SelectRealm:update(dt)
    if not self.realms or #self.realms == 0 or self.selectedIdx == 0 then return end
    input_timer = math.max(0, input_timer - dt)
    if input_timer == 0 then
        if love.keyboard.isDown('down') then
            self.selectedIdx = math.min(self.selectedIdx + 1, #self.realms)
            input_timer = input_delay
        elseif love.keyboard.isDown('up') then
            self.selectedIdx = math.max(self.selectedIdx - 1, 1)
            input_timer = input_delay
        elseif love.keyboard.isDown('return') or love.keyboard.isDown('space') then
            if self.realms[self.selectedIdx] then
                local Game = require 'src.game'
                print('DEBUG: SelectRealm:update - passing self.selectedCharacter to Game:', self.selectedCharacter and self.selectedCharacter.name or 'NIL', tostring(self.selectedCharacter))
                if self.selectedCharacter then
                    Game:selectCharacter(self.selectedCharacter)
                end
                Game:selectRealm(self.realms[self.selectedIdx])
                Gamestate.switch(Game, self.selectedCharacter)
            end
            input_timer = input_delay
        elseif love.keyboard.isDown('escape') then
            local SelectCharacter = require 'src.ui.select_character'
            Gamestate.switch(SelectCharacter)
            input_timer = input_delay
        end
    end
end

function SelectRealm:keypressed(key)
    if key == 'down' then
        if #self.realms > 0 then
            self.selectedIdx = math.min(self.selectedIdx + 1, #self.realms)
        end
    elseif key == 'up' then
        if #self.realms > 0 then
            self.selectedIdx = math.max(self.selectedIdx - 1, 1)
        end
    elseif key == 'return' or key == 'kpenter' then
        if #self.realms > 0 then
            if self.realms[self.selectedIdx] then
                local Game = require 'src.game'
                print('DEBUG: SelectRealm:keypressed - passing self.selectedCharacter to Game:', self.selectedCharacter and self.selectedCharacter.name or 'NIL', tostring(self.selectedCharacter))
                if self.selectedCharacter then
                    Game:selectCharacter(self.selectedCharacter)
                end
                Game:selectRealm(self.realms[self.selectedIdx])
                Gamestate.switch(Game, self.selectedCharacter)
            end
        end
    elseif key == 'escape' then
        local SelectCharacter = require 'src.ui.select_character'
        Gamestate.switch(SelectCharacter)
    end
end

function SelectRealm:draw()
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    -- Modern animated gradient background
    for i=0, wh, 2 do
        local t = i/wh
        love.graphics.setColor(0.13*(1-t)+0.22*t, 0.16*(1-t)+0.25*t, 0.23*(1-t)+0.34*t + 0.03*math.sin(love.timer.getTime()*0.7+i*0.01), 1)
        love.graphics.rectangle('fill', 0, i, ww, 2)
        if i%18==0 then
            love.graphics.setColor(0.12,0.18,0.28,0.10+0.08*math.abs(math.sin(love.timer.getTime()*0.5+i*0.02)))
            for x=0,ww,40 do
                love.graphics.circle('fill', x, i, 8+2*math.sin(love.timer.getTime()+x*0.01+i*0.01))
            end
        end
    end
    -- Title with animated shadow
    love.graphics.setFont(fontRealmTitle)
    for dx=-2,2 do for dy=-2,2 do
        if dx~=0 or dy~=0 then
            love.graphics.setColor(0,0,0,0.18-0.02*math.abs(dx*dy))
            love.graphics.printf('Select Realm', 2+dx, 42+dy, ww, 'center')
        end
    end end
    love.graphics.setColor(1,1,1)
    love.graphics.printf('Select Realm', 2, 42, ww, 'center')
    -- Add animated realm icon
    local realmPulse = 0.9+0.1*math.sin(love.timer.getTime()*2.4)
    love.graphics.setColor(1*realmPulse,0.7*realmPulse,0.2*realmPulse,0.7)
    love.graphics.circle('fill', ww/2, 120, 24+4*realmPulse, 48)
    love.graphics.setColor(1,1,1,0.18)
    love.graphics.circle('line', ww/2, 120, 28+5*realmPulse, 48)
    love.graphics.setFont(fontRealmDescription)
    love.graphics.setColor(0.8,0.9,1,0.92)
    love.graphics.printf('Choose a realm to challenge. Each one has unique rules and enemies!', 0, 80, ww, 'center')
    -- Realm cards
    local startY = 140
    for i, realm in ipairs(self.realms or {}) do
        local y = startY + (i-1) * 80
        local isSelected = (i == self.selectedIdx)
        -- Card shadow
        if isSelected then
            love.graphics.setColor(0,0,0,0.18)
            love.graphics.rectangle('fill', ww/2-184, y-14, 368, 68, 22, 22)
        end
        -- Card background with animated border
        if isSelected then
            local pulse = 0.95+0.05*math.sin(love.timer.getTime()*3)
            love.graphics.setColor(0.2*pulse,0.7*pulse,1*pulse, 0.22+0.08*pulse)
            love.graphics.rectangle('fill', ww/2-180, y-10, 360, 60, 18, 18)
            love.graphics.setColor(1, 0.85, 0.2, 0.9)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle('line', ww/2-180, y-10, 360, 60, 18, 18)
            love.graphics.setLineWidth(1)
        else
            love.graphics.setColor(0.2,0.2,0.2,0.7)
            love.graphics.rectangle('fill', ww/2-180, y-10, 360, 60, 18, 18)
        end
        -- Realm name
        love.graphics.setFont(fontRealmName)
        love.graphics.setColor(1,1,1)
        love.graphics.printf(realm.name or ("Realm "..i), ww/2-170, y, 340, 'left')
        -- Realm description
        love.graphics.setFont(fontRealmDescription)
        love.graphics.setColor(0.8,0.9,1,0.92)
        love.graphics.printf(realm.description or '', ww/2-170, y+22, 340, 'left')
    end
    -- Footer
    love.graphics.setFont(fontRealmFooter)
    love.graphics.setColor(0.7,0.9,1,0.7)
    love.graphics.printf('Use ↑/↓ to select, Enter/Space to confirm, Esc to return', 0, wh-60, ww, 'center')
    love.graphics.setColor(0.8,0.9,1,0.7)
    love.graphics.printf('Each realm has unique enemies and rules. Good luck!', 0, wh-36, ww, 'center')
end

return SelectRealm
