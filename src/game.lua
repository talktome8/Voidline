local love = require "love"
local Gamestate = require 'hump.gamestate' -- Added this line
local Game = {}
local Grid = require 'src.grid'
local Player = require 'src.player'
local enemiesLib = require 'src.enemy.init'
local Architect = require 'src.characters.architect'
local Trickster = require 'src.characters.trickster'
local VoidHatchery = require 'src.realms.void_hatchery'
local EchoLab = require 'src.realms.echo_lab'
local PulseMines = require 'src.realms.pulse_mines' -- Added PulseMines

-- Require the EndRun state correctly
local EndRun = require 'src.ui.endrun' 

-- enemies table
local enemies = {} -- Enemy list for the current level
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
-- Only the first character is unlocked at the start; others unlock as you progress
local unlockedCharacters = {1} -- Only Architect (or first character) is unlocked initially
local characterUnlockLevels = {
    [2] = 2,   -- Trickster unlocks after boss at level 2
    [3] = 4,   -- Guardian unlocks after boss at level 4
    [4] = 6,   -- Echo unlocks after boss at level 6
    [5] = 8,   -- Sprinter unlocks after boss at level 8
    [6] = 10,  -- Scorer unlocks after boss at level 10
}
local characterUnlockPending = {} -- Tracks which unlocks are pending boss defeat
local unlockMessage = nil
local unlockMessageTimer = 0
local unlockMessageDuration = 3
local realms = {VoidHatchery, EchoLab, PulseMines} -- Added PulseMines to realms
local currentRealmIdx = 1 -- Will be superseded by selectedRealm object
local currentRealm = realms[currentRealmIdx] -- Initial default

-- Make selectedCharacter and selectedRealm global variables (not attached to Game)
selectedCharacter = nil
selectedRealm = nil

local function getCharacterByName(name)
    local characters = require('src.characters.init')
    for _, char in ipairs(characters) do
        if char.name == name then return char end
    end
    return characters[1] -- fallback to first
end

-- Function called when this state is entered for the first time or via Gamestate.switch
function Game:enter(...)
    local args = {...}
    local foundCharacter = false
    local canonicalChar = nil
    for _, arg in ipairs(args) do
        if arg and arg.name and arg.description and arg.passives then
            canonicalChar = getCharacterByName(arg.name)
            selectedCharacter = canonicalChar
            _G.selectedCharacter = canonicalChar
            foundCharacter = true
            print('DEBUG: Game:enter - selectedCharacter set to', canonicalChar.name, tostring(canonicalChar))
            if type(arg) == 'table' then
                for k,v in pairs(arg) do print('DEBUG: Game:enter arg['..tostring(k)..']='..tostring(v)) end
            end
        elseif arg and arg.name and arg.description then
            Game:selectRealm(arg)
        end
    end
    -- Only use _G.selectedCharacter if nothing was passed at all
    if not foundCharacter then
        if _G.selectedCharacter then
            canonicalChar = getCharacterByName(_G.selectedCharacter.name)
            selectedCharacter = canonicalChar
            print('DEBUG: Game:enter - fallback to _G.selectedCharacter:', canonicalChar.name, tostring(canonicalChar))
        else
            selectedCharacter = getCharacterByName("Architect")
            print('DEBUG: Game:enter - fallback to Architect')
        end
    end
    print('DEBUG: Game:enter - final selectedCharacter:', selectedCharacter.name, tostring(selectedCharacter))
    self:load()
end

function Game:resume(poppedState, outcomeString)
    print("Game:resume called. Popped state type: " .. type(poppedState) .. ", Outcome string: " .. tostring(outcomeString) .. ", current level before increment: " .. level)
    if outcomeString == "win" then
        -- Check if a character should be unlocked after this boss level
        for idx, unlockLevel in pairs(characterUnlockLevels) do
            if level == unlockLevel and not self:isCharacterUnlocked(idx) then
                characterUnlockPending[idx] = true
            end
        end
        -- Actually unlock after boss is defeated (on win)
        for idx, pending in pairs(characterUnlockPending) do
            if pending then
                self:unlockCharacter(idx)
                unlockMessage = (characters[idx].name or ("Character #"..idx)) .. " unlocked!"
                unlockMessageTimer = unlockMessageDuration
                characterUnlockPending[idx] = nil
            end
        end
        level = level + 1
        print("Game:resume - Level incremented to: ", level)
    elseif outcomeString == "gameOver" then
        print("Game:resume - Game Over. Reloading level: ", level)
    end
    self:load()
end

function Game:load()
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    print("Game:load() - Loading level: ", level)
    print("Game:load() - selectedCharacter:", selectedCharacter and selectedCharacter.name or 'NIL', tostring(selectedCharacter))
    -- Map variety: each level changes grid size, realm, enemies
    local margin = 32
    local gridW, gridH = 24, 16
    if level % 3 == 2 then gridW, gridH = 28, 14 end
    if level % 3 == 0 then gridW, gridH = 20, 20 end
    Grid.width = gridW
    Grid.height = gridH
    Grid:setSizeToWindow(ww, wh, margin)
    Grid:load()
    enemies = {}
    -- Character unlock logic: only mark unlock as pending if boss is present and not yet defeated
    for idx, unlockLevel in pairs(characterUnlockLevels) do
        if level == unlockLevel and not self:isCharacterUnlocked(idx) and not characterUnlockPending[idx] then
            characterUnlockPending[idx] = false
        end
    end
    -- Always use selectedCharacter, fallback to Architect only if nil
    local characterToLoad = selectedCharacter or _G.selectedCharacter
    if not characterToLoad then
        characterToLoad = getCharacterByName("Architect")
        selectedCharacter = characterToLoad
        _G.selectedCharacter = characterToLoad
        print('DEBUG: Fallback to Architect!')
    else
        -- Always normalize to the canonical object from the array
        characterToLoad = getCharacterByName(characterToLoad.name)
        selectedCharacter = characterToLoad
        _G.selectedCharacter = characterToLoad
    end
    print('DEBUG: Game:load will use character:', characterToLoad and characterToLoad.name or 'NIL', tostring(characterToLoad))
    Player:load(Grid, characterToLoad)
    Player.character = characterToLoad
    print('DEBUG: Player.character is now:', Player.character and Player.character.name or 'NIL', tostring(Player.character))
    self:applyCharacterPassives()
    -- Enemy variety: each level adds/changes enemies
    if level % 3 == 0 then
        local reclaimer = enemiesLib.Reclaimer:new(Grid.width-2, 2, level)
        table.insert(enemies, reclaimer)
        local jammer = enemiesLib.Jammer:new(2, Grid.height-2, level)
        table.insert(enemies, jammer)
        if level % 5 == 0 then
            table.insert(enemies, enemiesLib.Jammer:new(Grid.width-3, 3, level))
        end
    elseif level % 2 == 0 then
        table.insert(enemies, enemiesLib.Chaser:new(Grid.width-1, Grid.height-1, level))
        table.insert(enemies, enemiesLib.Jammer:new(2, 2, level))
        if level > 6 then
            table.insert(enemies, enemiesLib.Chaser:new(2, Grid.height-2, level))
        end
    else
        table.insert(enemies, enemiesLib.Chaser:new(Grid.width-1, 2, level))
        table.insert(enemies, enemiesLib.Chaser:new(2, Grid.height-1, level))
        enemies[#enemies].moveDelay = 1.8
        if #enemies > 1 then enemies[#enemies-1].moveDelay = 1.8 end
        if level > 7 then
            table.insert(enemies, enemiesLib.Jammer:new(Grid.width-3, 2, level))
        end
    end
    -- Add more enemies as levels increase for challenge
    if level >= 4 then
        table.insert(enemies, enemiesLib.GuardianBreaker:new(Grid.width-2, Grid.height-2))
    end
    if level % 5 == 0 then
        table.insert(enemies, enemiesLib.ReclaimerBoss:new(math.floor(Grid.width/2), math.floor(Grid.height/2)))
    end

    for _, enemy in ipairs(enemies) do
        if enemy.type then
            self:applyEnemyPassives(enemy, level)
        end
    end
    -- Forced slow for all enemies on level 3,6,9... (must be after all passives)
    if level % 3 == 0 then
        for _, enemy in ipairs(enemies) do
            -- תקן: אל תאט אויבים מסוג Jammer מתחת ל-1.2 שניות
            if enemy.type == "Jammer" then
                enemy.moveDelay = math.max(tonumber(enemy.moveDelay) or 0, 1.2)
            else
                local delay = tonumber(enemy.moveDelay) or 0
                enemy.moveDelay = math.max(delay, 2.5)
            end
            enemy._forcedSlow = true
            print('DEBUG: FINAL SLOWDOWN', enemy.type, 'moveDelay:', enemy.moveDelay)
        end
    end
    Grid.enemies = enemies
    gameOver = false
    win = false
    -- Realm variety
    currentRealm = selectedRealm or realms[((level-1) % #realms) + 1]
    Grid:setRequiredClaimedPercent(requiredPercents[level] or 0.8)
    print("Game:load() - Required percent for level " .. level .. " is " .. (requiredPercents[level] or 0.8) * 100 .. "%")
    startTime = love.timer.getTime()
    elapsedTime = 0
    autoRestartTimer = 0
    score = 0
    -- Character/enemy ability hooks (for future improvements)
    if Player.character and Player.character.onLevelStart then
        Player.character:onLevelStart(level, Grid)
    end
    for _, enemy in ipairs(enemies) do
        if enemy.onLevelStart then
            enemy:onLevelStart(level, Grid)
        end
    end
    print('DEBUG: FINAL selectedCharacter:', selectedCharacter and selectedCharacter.name or 'NIL')
    for _, enemy in ipairs(enemies) do
        print('DEBUG: ENEMY', enemy.type, 'moveDelay:', enemy.moveDelay, '_forcedSlow:', enemy._forcedSlow)
    end
end

function Game:addScore(points)
    score = score + points
end

-- Add pause/reset
local paused = false
function Game:update(dt)
    if unlockMessage then
        unlockMessageTimer = unlockMessageTimer - dt
        if unlockMessageTimer <= 0 then
            unlockMessage = nil
        end
    end
    if love.keyboard.isDown('p') then paused = not paused end
    if love.keyboard.isDown('r') then self:load() end
    if paused then return end

    if gameOver or win then
        local idx = currentCharacterIdx or 1
        if not characters[unlockedCharacters[idx]] then idx = 1 end
        local statsTable = {
            level = level,
            characterName = (selectedCharacter and selectedCharacter.name)
                or (Player.character and Player.character.name)
                or (characters[unlockedCharacters[idx]].name),
            claimedPercent = math.floor(Grid:getClaimedPercent()*100),
            requiredPercent = math.floor(Grid.requiredClaimedPercent*100),
            areaCleared = (Grid.width-2)*(Grid.height-2), 
            score = score,
            deaths = deaths,
            wins = wins,
            -- outcome is passed as a separate param to EndRun:enter
        }
        local currentOutcome = win and "win" or "gameOver"
        Gamestate.push(EndRun, currentOutcome, statsTable) -- Use push to go to EndRun
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

        -- Player's current node
        local p_node_i, p_node_j = Player.i, Player.j

        -- 1. Direct collision with player's current position (node)
        -- An enemy in a cell is considered colliding if its cell is one of the 4 around the player's node.
        local cells_around_player_node = {
            {i = p_node_i - 1, j = p_node_j - 1}, {i = p_node_i, j = p_node_j - 1}, -- Top-left, Top-right cells relative to node
            {i = p_node_i - 1, j = p_node_j},     {i = p_node_i, j = p_node_j}      -- Bottom-left, Bottom-right cells relative to node
        }
        for _, cell_coord in ipairs(cells_around_player_node) do
            if Grid:isInside(cell_coord.i, cell_coord.j) then
                if enemy.i == cell_coord.i and enemy.j == cell_coord.j then
                    print("Enemy direct collision with player at node vicinity: PNode("..p_node_i..","..p_node_j..") ECell("..enemy.i..","..enemy.j..")")
                    gameOver = true; deaths = deaths + 1; break
                end
            end
        end
        if gameOver then break end -- Break from enemies loop if collision detected

        -- 2. Collision with player's active trail
        if Player.isDrawing and #Player.trail >= 2 then
            for k = 1, #Player.trail - 1 do
                local n1 = Player.trail[k] -- Start node of trail segment
                local n2 = Player.trail[k+1] -- End node of trail segment
                local ei, ej = enemy.i, enemy.j -- Enemy's cell coordinates

                local hit_trail_segment = false
                if n1.i == n2.i then -- Vertical trail segment (nodes share same i, form a vertical line)
                    -- This node line is at x-coordinate n1.i.
                    -- It separates cell column (n1.i - 1) from cell column n1.i.
                    -- The relevant cell row for collision is the one corresponding to the start of the node segment, which is min(n1.j, n2.j).
                    if ej == math.min(n1.j, n2.j) then -- Enemy is in a cell row that aligns with the vertical trail segment
                        if ei == n1.i - 1 or ei == n1.i then -- Enemy is in one of the two cell columns adjacent to the vertical node line
                            hit_trail_segment = true
                        end
                    end
                elseif n1.j == n2.j then -- Horizontal trail segment (nodes share same j, form a horizontal line)
                    -- This node line is at y-coordinate n1.j.
                    -- It separates cell row (n1.j - 1) from cell row n1.j.
                    -- The relevant cell column for collision is the one corresponding to the start of the node segment, which is min(n1.i, n2.i).
                    if ei == math.min(n1.i, n2.i) then -- Enemy is in a cell column that aligns with the horizontal trail segment
                        if ej == n1.j - 1 or ej == n1.j then -- Enemy is in one of the two cell rows adjacent to the horizontal node line
                            hit_trail_segment = true
                        end
                    end
                end

                if hit_trail_segment then
                    print("Enemy collided with player trail segment between N("..n1.i..","..n1.j..") and N("..n2.i..","..n2.j.."). Enemy at C("..ei..","..ej..")")
                    
                    if not Player.isFuseActive then
                        Player.isFuseActive = true
                        Player.fuseTimer = Player.fuseDuration
                        Player.fusedEnemy = enemy -- Store the enemy
                        
                        -- Store a copy of the current trail for the burning effect
                        Player.burningTrail = shallowcopy(Player.trail) 
                        -- Store the index of the *start node* of the hit segment
                        -- Player.trail[k] is the start node (n1)
                        Player.fuseHitSegmentIndex = k 

                        print(string.format("Fuse activated! Burning trail from segment %d. Trail length: %d", k, #Player.burningTrail))
                        -- Sound.play('fuse_activate') -- Example sound effect
                    end
                    -- Do not set gameOver = true here anymore, let the fuse timer handle it
                end
            end
            -- if gameOver then break end -- No longer needed here as fuse handles game over
        end

        -- Old trail collision logic (based on Grid.cells[i][j] == 'trail') is removed as it's not compatible with node-based trails.
        -- The old direct collision (enemy.i == Player.i and enemy.j == Player.j) was also incorrect.
    end
    -- Check win condition
    if Grid:getClaimedPercent() >= Grid.requiredClaimedPercent then
        win = true
        wins = wins + 1
    end
end

-- Add: Show which character will unlock at the next boss level
function Game:getNextUnlockInfo()
    local nextLevel, nextIdx = nil, nil
    for idx, unlockLevel in pairs(characterUnlockLevels) do
        if not self:isCharacterUnlocked(idx) and (not nextLevel or unlockLevel < nextLevel) and unlockLevel >= level then
            nextLevel = unlockLevel
            nextIdx = idx
        end
    end
    if nextLevel and nextIdx then
        return nextLevel, characters[nextIdx] and characters[nextIdx].name or ("Character #"..nextIdx)
    end
    return nil, nil
end

-- Add: Enemy passives and escalation for higher levels
function Game:applyEnemyPassives(enemy, level)
    if enemy._forcedSlow then
        -- Do not override moveDelay or any parameter if enemy was forcibly slowed
        return
    end
    if enemy.type == "Chaser" and level >= 7 then
        enemy.moveDelay = math.max(0.4, (enemy.moveDelay or 1) * 0.85)
        enemy.smartChase = true -- Smarter pathfinding at high levels
    elseif enemy.type == "Jammer" and level >= 8 then
        enemy.jamRadius = (enemy.jamRadius or 2) + 1
    elseif enemy.type == "GuardianBreaker" and level >= 10 then
        enemy.breakSpeed = (enemy.breakSpeed or 1) * 1.2
    elseif enemy.type == "ReclaimerBoss" then
        enemy.moveDelay = math.max(0.3, (enemy.moveDelay or 1) * (0.95 - 0.01 * level))
        enemy.extraAttack = level >= 12
    end
end

function Game:draw()
    Grid:draw()
    Player:draw(Grid)
    for _, enemy in ipairs(enemies) do
        enemy:draw(Grid)
    end

    -- HUD: character, ability, cooldown
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.setColor(0.13,0.13,0.18,0.85)
    love.graphics.rectangle('fill', 12, 12, 220, 60, 10, 10)
    love.graphics.setColor(1,1,1)
    local char = Player.character or selectedCharacter
    love.graphics.print('Character: '..(char and char.name or 'N/A'), 24, 24)
    if char and char.activeAbilityName then
        love.graphics.setColor(0.8,0.9,1)
        love.graphics.print('Ability: '..char.activeAbilityName, 24, 44)
        if Player.abilityCooldown then
            love.graphics.setColor(1,0.7,0.2)
            love.graphics.print('Cooldown: '..string.format('%.1f', Player.abilityCooldown), 140, 44)
        end
    end
    love.graphics.setColor(1,1,1)

    -- Minimized In-Game Statistics (Top Right)
    if not gameOver and not win then
        local percent = math.floor(Grid:getClaimedPercent()*100)
        local req = math.floor(Grid.requiredClaimedPercent*100)
        local character = selectedCharacter or self.selectedCharacter or Player.character or characters[unlockedCharacters[1]]
        local minimizedPanelW, minimizedPanelH = 220, 100
        local mpx, mpy = love.graphics.getWidth() - minimizedPanelW - 10, 10
        love.graphics.setColor(0.95,0.95,0.95,0.6)
        love.graphics.rectangle('fill', mpx, mpy, minimizedPanelW, minimizedPanelH, 8, 8)
        love.graphics.setColor(0.1,0.1,0.1)
        love.graphics.setFont(love.graphics.newFont(11))
        love.graphics.print('Lvl: '..level, mpx+8, mpy+5)
        love.graphics.print('Char: '..(character and character.name or 'N/A'), mpx+8, mpy+20)
        love.graphics.print('Claimed: '..percent..'/'..req..'%', mpx+8, mpy+35)
        love.graphics.print('Unlocked: '..#unlockedCharacters..'/'..#characters, mpx+8, mpy+50)
        -- Show next unlock info
        local nextUnlockLevel, nextUnlockName = self:getNextUnlockInfo()
        if nextUnlockLevel then
            love.graphics.setColor(0.2,0.5,1,0.8)
            love.graphics.print('Next unlock: '..nextUnlockName..' (after boss L'..nextUnlockLevel..')', mpx+8, mpy+70)
            love.graphics.setColor(0.1,0.1,0.1)
        end
        -- Show passive of current character
        love.graphics.setColor(0.1,0.7,0.1,0.8)
        love.graphics.print('Passive: '..self:getCharacterPassiveDescription(character), mpx+8, mpy+85)
        love.graphics.setColor(0.1,0.1,0.1)
    end

    -- Fuse warning message
    if Player.isFuseActive then
        love.graphics.setFont(love.graphics.newFont(22))
        love.graphics.setColor(1,0.3,0.1,0.85)
        love.graphics.printf('! FUSE ACTIVATED - RETURN TO THE FRAME !', 0, 30, love.graphics.getWidth(), 'center')
        love.graphics.setColor(1,1,1)
    end

    -- Show unlock message if present
    if unlockMessage then
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.setColor(0.2, 0.8, 0.2, 0.85)
        love.graphics.printf(unlockMessage, 0, 70, love.graphics.getWidth(), 'center')
        love.graphics.setColor(1,1,1)
    end

    love.graphics.setFont(love.graphics.newFont(16)) -- Reset font for other UI elements
    love.graphics.setColor(1,1,1)

    -- The detailed end-of-round drawing is now handled by EndRun:draw()
end

function Game:keypressed(key)
    if key == 'p' then paused = not paused end
    if key == 'r' then self:load() end
    -- All keypress logic for win/gameOver states is now in EndRun:keypressed
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
        _G.selectedCharacter = character_obj
        print("Character selected: " .. (character_obj.name or "Unknown"))
        for i, char in ipairs(characters) do
            if char == character_obj then
                currentCharacterIdx = i
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
        currentRealm = realm_obj
        print("Realm selected: " .. (realm_obj.name or "Unknown"))
    else
        print("Error: Attempted to select a nil realm.")
    end
end

-- Utility: check if a character is unlocked
function Game:isCharacterUnlocked(idx)
    for _, unlockedIdx in ipairs(unlockedCharacters) do
        if unlockedIdx == idx then return true end
    end
    return false
end

-- Utility: get character index from object
function Game:getCharacterIndex(character_obj)
    for i, char in ipairs(characters) do
        if char == character_obj then return i end
    end
    return 1 -- fallback to first
end

-- Add: Give each character a passive bonus (example: speed, score, etc.)
function Game:applyCharacterPassives()
    if not Player.character then return end
    if Player.character.name == "Trickster" then
        Player.speed = (Player.baseSpeed or 1) * 1.15
    elseif Player.character.name == "Guardian" then
        Player.maxLives = 2
    elseif Player.character.name == "Echo" then
        Player.trailLengthBonus = 2
    elseif Player.character.name == "Sprinter" then
        Player.speed = (Player.baseSpeed or 1) * 1.25
    elseif Player.character.name == "Scorer" then
        Player.scoreMultiplier = 1.5
    else
        -- Default/Architect
        Player.speed = Player.baseSpeed or 1
        Player.maxLives = 1
        Player.trailLengthBonus = 0
        Player.scoreMultiplier = 1
    end
end

-- Add: Show character passive in stats panel
function Game:getCharacterPassiveDescription(character)
    if not character then return "" end
    if character.name == "Trickster" then
        return "+15% speed"
    elseif character.name == "Guardian" then
        return "+1 extra life"
    elseif character.name == "Echo" then
        return "+2 trail length"
    elseif character.name == "Sprinter" then
        return "+25% speed"
    elseif character.name == "Scorer" then
        return "1.5x score"
    else
        return "Balanced"
    end
end

-- Expose characterUnlockLevels to other modules (for select_character.lua to show unlock info).
Game.characterUnlockLevels = characterUnlockLevels

return Game
