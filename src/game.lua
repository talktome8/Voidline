local Game = {}
local Grid = require 'src.grid'
local Player = require 'src.player'
local enemiesLib = require 'src.enemy.init'
local Architect = require 'src.characters.architect'
local Trickster = require 'src.characters.trickster'
local VoidHatchery = require 'src.realms.void_hatchery'
local EchoLab = require 'src.realms.echo_lab'

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
local characters = require('src.characters.init')
local unlockedCharacters = {1, 2, 3, 4, 5, 6} -- כל הדמויות פתוחות לדמו
local currentCharacterIdx = 1
local realms = {VoidHatchery, EchoLab}
local currentRealmIdx = 1
local currentRealm = realms[currentRealmIdx]

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
    -- Alternate character each level for demo
    -- פותח דמויות חדשות לפי שלבים
    if level >= 3 and not unlockedCharacters[3] then
        self:unlockCharacter(3)
    end
    local character = characters[unlockedCharacters[currentCharacterIdx] or 1]
    Player:load(Grid, character)
    enemies = {}
    -- שלבים מתקדמים: מוסיפים אויבים מגוונים
    table.insert(enemies, enemiesLib.Chaser:new(Grid.width-1, Grid.height-1))
    if level >= 2 then
        table.insert(enemies, enemiesLib.Reclaimer:new(2, 2))
    end
    if level >= 3 then
        table.insert(enemies, enemiesLib.Jammer:new(Grid.width-2, 2))
    end
    Grid.enemies = enemies
    gameOver = false
    win = false
    currentRealm = realms[((level-1) % #realms) + 1]
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
    -- Realm-specific update (for echo effect, etc)
    if currentRealm and currentRealm.update then
        currentRealm:update(dt, Grid)
    end
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

-- Patch Player to notify realm on zone closure
local origPlayerUpdate = Player.update
function Player:update(dt, grid)
    local beforeClaimed = grid:getClaimedPercent()
    origPlayerUpdate(self, dt, grid)
    local afterClaimed = grid:getClaimedPercent()
    if afterClaimed > beforeClaimed then
        if currentRealm and currentRealm.onZoneClosed then
            currentRealm:onZoneClosed(grid)
        end
        -- Apply Architect's passive ability
        if self.character and self.character.name == "Architect" then
            for _, enemy in ipairs(enemies) do
                if enemy.setFrozen then -- Check if the enemy has the setFrozen method
                    enemy:setFrozen(1) -- Freeze for 1 second
                end
            end
        end
    end
end

function Game:draw()
    Grid:draw()
    Player:draw(Grid)
    for _, enemy in ipairs(enemies) do
        enemy:draw(Grid)
    end
    -- Modern statistics panel (top right, semi-transparent, small font)
    local percent = math.floor(Grid:getClaimedPercent()*100)
    local req = math.floor(Grid.requiredClaimedPercent*100)
    local area = (Grid.width-2)*(Grid.height-2)
    local character = characters[(currentCharacterIdx-1) % #characters + 1]
    local panelW, panelH = 210, 90
    local px, py = love.graphics.getWidth() - panelW - 10, 10
    love.graphics.setColor(0.95,0.95,0.95,0.7)
    love.graphics.rectangle('fill', px, py, panelW, panelH, 10, 10)
    love.graphics.setColor(0.1,0.1,0.1)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print('Lvl: '..level, px+10, py+6)
    love.graphics.print('Char: '..character.name, px+10, py+22)
    love.graphics.print('Claimed: '..percent..'/'..req..'%', px+10, py+38)
    love.graphics.print('Area: '..area, px+10, py+54)
    love.graphics.print('D:'..deaths..' W:'..wins, px+10, py+70)
    love.graphics.setFont(love.graphics.newFont(16))
    -- Realm info (bottom right, small font)
    love.graphics.setFont(love.graphics.newFont(11))
    love.graphics.setColor(0.95,0.95,0.95,0.6)
    love.graphics.printf('Realm: '..currentRealm.name, px, py+panelH+2, panelW, 'left')
    love.graphics.printf(currentRealm.description, px, py+panelH+16, panelW, 'left')
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.setColor(1,1,1)
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
        currentCharacterIdx = currentCharacterIdx % #characters + 1
        self:load()
    elseif gameOver then
        self:load()
    end
end

function Game:unlockCharacter(idx)
    if not unlockedCharacters[idx] then
        table.insert(unlockedCharacters, idx)
    end
end

function Game:selectCharacter(idx)
    if unlockedCharacters[idx] then
        currentCharacterIdx = idx
    end
end

return Game
