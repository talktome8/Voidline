local Game = {}
local Grid = require 'src.grid'
local Player = require 'src.player'
local Chaser = require 'src.enemy.chaser'

-- enemies table
local enemies = {}
local gameOver = false
local win = false
local level = 1
local requiredPercents = {0.3, 0.4, 0.5, 0.6, 0.7, 0.8}
local deaths = 0
local wins = 0
local startTime = 0
local elapsedTime = 0
local autoRestartTimer = 0
local autoRestartDelay = 2

function Game:load()
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    -- Dynamically set grid size to maximize screen usage
    local margin = 32
    local cellSizeW = math.floor((ww - 2*margin) / 32)
    local cellSizeH = math.floor((wh - 2*margin) / 20)
    local cellSize = math.max(24, math.min(cellSizeW, cellSizeH))
    Grid.width = math.floor((ww - 2*margin) / cellSize)
    Grid.height = math.floor((wh - 2*margin) / cellSize)
    Grid:setSizeToWindow(ww, wh, margin)
    Grid:load()
    Player:load(Grid)
    enemies = {}
    -- Spawn chaser far from player (bottom right corner)
    table.insert(enemies, Chaser:new(Grid.width-1, Grid.height-1))
    gameOver = false
    win = false
    Grid:setRequiredClaimedPercent(requiredPercents[level] or 0.8)
    startTime = love.timer.getTime()
    elapsedTime = 0
    autoRestartTimer = 0
end

function Game:update(dt)
    if gameOver or win then
        autoRestartTimer = autoRestartTimer + dt
        if autoRestartTimer > autoRestartDelay then
            if win then
                level = level + 1
            end
            self:load()
        end
        return
    end
    elapsedTime = love.timer.getTime() - startTime
    Grid:update(dt)
    Player:update(dt, Grid)
    -- Enemy kills player if on same cell or on any trail cell (even if not drawing)
    for _, enemy in ipairs(enemies) do
        enemy:update(dt, Grid, Player)
        if enemy.i == Player.i and enemy.j == Player.j then
            gameOver = true
            deaths = deaths + 1
        end
        -- Check all trail cells on grid
        for i=1,Grid.width do
            for j=1,Grid.height do
                if Grid.cells[i][j] == 'trail' and enemy.i == i and enemy.j == j then
                    gameOver = true
                    deaths = deaths + 1
                end
            end
        end
    end
    -- Check win condition
    if Grid:getClaimedPercent() >= Grid.requiredClaimedPercent then
        win = true
        wins = wins + 1
    end
end

function Game:draw()
    Grid:draw()
    Player:draw(Grid)
    for _, enemy in ipairs(enemies) do
        enemy:draw(Grid)
    end
    -- Modern statistics panel (top left)
    local percent = math.floor(Grid:getClaimedPercent()*100)
    local req = math.floor(Grid.requiredClaimedPercent*100)
    local area = (Grid.width-2)*(Grid.height-2)
    love.graphics.setColor(0.95,0.95,0.95)
    love.graphics.rectangle('fill', 10, 10, 260, 110, 10, 10)
    love.graphics.setColor(0.1,0.1,0.1)
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.print('Level: '..level, 20, 20)
    love.graphics.print('Claimed: '..percent..'%'..' / '..req..'%', 20, 40)
    love.graphics.print('Area: '..area..' cells', 20, 60)
    love.graphics.print('Deaths: '..deaths..'   Wins: '..wins, 20, 80)
    love.graphics.print(string.format('Time: %.1fs', elapsedTime), 20, 100)
    love.graphics.setFont(love.graphics.newFont(16))
    if gameOver then
        love.graphics.setColor(1,0.2,0.2,0.8)
        love.graphics.printf('GAME OVER\nPress any key to restart', 0, Grid.offsetY + Grid.height*Grid.cellSize/2 - 40, love.graphics.getWidth(), 'center')
        love.graphics.setColor(1,1,1)
    elseif win then
        love.graphics.setColor(0.2,1,0.2,0.8)
        love.graphics.printf('WIN! Press any key for next level', 0, Grid.offsetY + Grid.height*Grid.cellSize/2 - 40, love.graphics.getWidth(), 'center')
        love.graphics.setColor(1,1,1)
    end
end

function Game:keypressed(key)
    if win then
        level = level + 1
        self:load()
    elseif gameOver then
        self:load()
    end
end

return Game
