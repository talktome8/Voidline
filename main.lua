-- Voidline main.lua
local Gamestate = require 'hump.gamestate'
local Menu = require 'src.ui.menu'
local Game = require 'src.game'
local EndRun = require 'src.ui.endrun'

function love.load()
    print('Voidline initialized')
    Gamestate.registerEvents()
    Gamestate.switch(Menu)
end
