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
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(fontLarge)
    love.graphics.printf("Select Realm", 0, 60, love.graphics.getWidth(), 'center')
    if not self.realms or #self.realms == 0 then
        love.graphics.setFont(fontMedium)
        love.graphics.printf("No realms available!", 0, love.graphics.getHeight()/2, love.graphics.getWidth(), 'center')
        return
    end
    local startY = 160
    for i, realm in ipairs(self.realms) do
        local y = startY + (i-1) * 90
        local isSelected = (i == self.selectedIdx)
        love.graphics.setColor(isSelected and 1 or 0.7, isSelected and 1 or 0.7, isSelected and 0.7 or 0.7, 0.9)
        love.graphics.rectangle('fill', 120, y, 420, 80, 12, 12)
        love.graphics.setColor(0.1,0.1,0.1)
        love.graphics.setFont(fontLarge)
        love.graphics.print(realm.name, 140, y+8)
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(0.2,0.2,0.2)
        love.graphics.printf(realm.description or "", 140, y+38, 390, 'left')
        love.graphics.setColor(1,1,1)
    end
end

return SelectRealm
