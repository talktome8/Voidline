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
local score = 0 -- Initialize score
local characters = require('src.characters.init')
local unlockedCharacters = {1, 2, 3, 4, 5, 6} -- כל הדמויות פתוחות לדמו
local currentCharacterIdx = 1 -- Will be superseded by selectedCharacter object
local realms = {VoidHatchery, EchoLab}
local currentRealmIdx = 1 -- Will be superseded by selectedRealm object
local currentRealm = realms[currentRealmIdx] -- Initial default

-- New variables to store player's explicit choices
local selectedCharacter = nil
local selectedRealm = nil

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
    -- Alternate character each level for demo -- This logic will be changed
    -- פותח דמויות חדשות לפי שלבים
    if level >= 3 and not unlockedCharacters[3] then -- This unlocking logic can remain
        self:unlockCharacter(3)
    end

    local characterToLoad = selectedCharacter or characters[unlockedCharacters[1]] -- Use selected or default
    Player:load(Grid, characterToLoad)
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
    -- Use selectedRealm if available, otherwise cycle or default
    currentRealm = selectedRealm or realms[((level-1) % #realms) + 1]
    Grid:setRequiredClaimedPercent(requiredPercents[level] or 0.8)
    startTime = love.timer.getTime()
    elapsedTime = 0
    autoRestartTimer = 0
    score = 0 -- Reset score on new game/level
end

function Game:addScore(points)
    score = score + points
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
    local character = selectedCharacter or characters[unlockedCharacters[1]] -- Use selected or default for display
    local panelW, panelH = 210, 110 -- Increased height for score
    local px, py = love.graphics.getWidth() - panelW - 10, 10
    love.graphics.setColor(0.95,0.95,0.95,0.7)
    love.graphics.rectangle('fill', px, py, panelW, panelH, 10, 10)
    love.graphics.setColor(0.1,0.1,0.1)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print('Lvl: '..level, px+10, py+6)
    love.graphics.print('Char: '..character.name, px+10, py+22)
    love.graphics.print('Claimed: '..percent..'/'..req..'%', px+10, py+38)
    love.graphics.print('Area: '..area, px+10, py+54)
    love.graphics.print('Score: '..score, px+10, py+70) -- Display score
    love.graphics.print('D:'..deaths..' W:'..wins, px+10, py+86) -- Adjusted y-pos
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
        -- currentCharacterIdx = currentCharacterIdx % #characters + 1 -- Removed auto-cycling
        self:load()
    elseif gameOver then
        self:load()
    end
end

function Game:unlockCharacter(idx)
    -- Check if the character (by index) is already conceptually unlocked
    local alreadyUnlocked = false
    for _, unlockedIdx in ipairs(unlockedCharacters) do
        if unlockedIdx == idx then
            alreadyUnlocked = true
            break
        end
    end
    if not alreadyUnlocked then
        table.insert(unlockedCharacters, idx)
        -- Potentially provide feedback to the player here if desired
        print("Unlocked character at index: " .. idx)
    end
end

-- Modified to accept character object
function Game:selectCharacter(character_obj)
    if character_obj then
        selectedCharacter = character_obj
        print("Character selected: " .. (character_obj.name or "Unknown"))
        -- Find index for compatibility if needed elsewhere, though direct object usage is preferred
        for i, char in ipairs(characters) do
            if char == character_obj then
                currentCharacterIdx = i -- Keep currentCharacterIdx for now if other logic relies on it
                break
            end
        end
    else
        print("Error: Attempted to select a nil character.")
    end
end

-- New function to accept realm object
function Game:selectRealm(realm_obj)
    if realm_obj then
        selectedRealm = realm_obj
        currentRealm = realm_obj -- Immediately set currentRealm as well
        print("Realm selected: " .. (realm_obj.name or "Unknown"))
    else
        print("Error: Attempted to select a nil realm.")
    end
end

return Game
