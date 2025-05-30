local Game = {}
local Grid = require 'src.grid'
local Player = require 'src.player'

function Game:load()
    Grid:load()
    Player:load(Grid)
end

function Game:update(dt)
    Grid:update(dt)
    Player:update(dt, Grid)
end

function Game:draw()
    Grid:draw()
    Player:draw(Grid)
end

return Game
