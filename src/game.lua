-- src/game.lua
-- Central game state machine and main game loop. Handles level flow, enemy/player/grid updates, and delegates UI overlays to the HUD module.

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
local IngameHUD = require 'src.ui.ingame_hud'
local Achievements = require('src.ui.achievements')

local Sound = require('src.utils.sound')

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

function Game:resume(poppedState, outcomeString, stagesArg)
    local stages = stagesArg or require('src.stages.init')
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
        win = false
        gameOver = false
        self:load()
        return
    elseif outcomeString == "gameOver" then
        print("Game:resume - Game Over. Reloading level: ", level)
        Sound.play('death')
        win = false
        gameOver = false
        self:load()
        return
    end
    -- === Achievements logic ===
    -- 1. Close 90% in a single run
    if Grid and Grid.getClaimedPercent and Grid:getClaimedPercent() >= 0.9 then
        Achievements:unlock("close90")
    end
    -- 2. Defeat boss (if current stage is boss)
    local stageIdx = ((level-1) % #stages) + 1
    local stage = stages[stageIdx]
    if outcomeString == "win" and stage and stage.name and string.lower(stage.name):find("boss") then
        Achievements:unlock("defeatBoss")
        Sound.play('boss')
    end
    -- 3. Win with every character
    if outcomeString == "win" and selectedCharacter and selectedCharacter.name then
        Achievements.personal["win_"..selectedCharacter.name] = true
        local allWon = true
        for _, char in ipairs(characters) do
            if not Achievements.personal["win_"..char.name] then allWon = false end
        end
        if allWon then Achievements:unlock("allChars") end
    end
    -- 4. Win a stage without dying
    if outcomeString == "win" and deaths == 0 then
        Achievements:unlock("noDeath")
    end
    -- === Endrun stats logic ===
    local statsTable = {
        level = level,
        characterName = (selectedCharacter and selectedCharacter.name) ~= nil and (selectedCharacter and selectedCharacter.name)
            or ((Player.character and Player.character.name) ~= nil and (Player.character and Player.character.name))
            or (characters[unlockedCharacters[1]].name),
        claimedPercent = math.floor(Grid:getClaimedPercent()*100),
        requiredPercent = math.floor(Grid.requiredClaimedPercent*100),
        areaCleared = (Grid.width-2)*(Grid.height-2),
        score = score,
        deaths = deaths,
        wins = wins,
        zonesClosed = zonesClosed or 0,
        abilitiesUsed = Player.abilitiesUsed or 0,
        bossesDefeated = bossesDefeated or 0,
        -- outcome is passed as a separate param to EndRun:enter
    }
    local currentOutcome = win and "win" or "gameOver"
    Gamestate.push(EndRun, currentOutcome, statsTable)
    return
end

local stages = require('src.stages.init')
Game.stages = stages
function Game:load()
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    print("Game:load() - Loading level: ", level)
    -- Stage system: pick stage by level (cycle if needed)
    local stageIdx = ((level-1) % #stages) + 1
    local stage = stages[stageIdx]
    print("Stage:", stage.name)
    -- Grid size and percent
    local gridW, gridH = stage.gridW or 24, stage.gridH or 16
    Grid.width = gridW
    Grid.height = gridH
    Grid:setSizeToWindow(ww, wh, 32)
    Grid:load()
    enemies = {}
    powerups = {}
    powerupSpawnTimer = 0
    -- Enemies for this stage
    for _, e in ipairs(stage.enemies(level, enemiesLib, Grid)) do table.insert(enemies, e) end
    -- PowerUps for this stage (always pass PowerUps table)
    local powerupsList = {}
    if stage.powerups then
        powerupsList = stage.powerups(level, _G.PowerUps or PowerUps, Grid) or {}
    else
        -- Add Freeze powerup every 3rd level as דוגמה
        if level % 3 == 0 then table.insert(powerupsList, PowerUps.Freeze) end
    end
    for _, pu in ipairs(powerupsList) do table.insert(powerups, pu) end
    -- Special rules for this stage
    if stage.special then stage.special(self, Player, Grid) end

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
    -- Apply per-character, per-stage modifiers
    if Player.character and Player.character.characterStageModifier then
        Player.character:characterStageModifier(stage, Player, Grid)
    end
    -- After stage.special, all enemy logic is now handled by the stage definition

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

    -- יציבות אויבים: מניעת הופעה על מכשול או תא חסום
    for _, enemy in ipairs(enemies) do
        if Grid.cells[enemy.i] and (Grid.cells[enemy.i][enemy.j] == 'obstacle' or Grid.cells[enemy.i][enemy.j] == 'claimed') then
            -- מצא תא פנוי קרוב
            for di=-1,1 do for dj=-1,1 do
                local ni, nj = enemy.i+di, enemy.j+dj
                if Grid:isInside(ni, nj) and Grid.cells[ni] and Grid.cells[ni][nj] == 'empty' then
                    enemy.i, enemy.j = ni, nj
                    break
                end
            end end
        end
    end

    -- ייצוב תנועת אויבים: מניעת תנועה למכשול/קיר
    for _, enemy in ipairs(enemies) do
        local oldUpdate = enemy.update
        enemy.update = function(self, dt, grid, player)
            local prevI, prevJ = self.i, self.j
            oldUpdate(self, dt, grid, player)
            if grid.cells[self.i] and (grid.cells[self.i][self.j] == 'obstacle' or grid.cells[self.i][self.j] == 'claimed') then
                self.i, self.j = prevI, prevJ -- לא לזוז למכשול
            end
        end
    end

    -- Modular: All character-specific stage logic is now handled in characterStageModifier in each character module.
    -- Remove hardcoded logic for vision, obstacles, etc. from here.
end

function Game:addScore(points)
    score = score + points
end

-- Add pause/reset
local paused = false
local fps = 0
local fpsTimer = 0
local fpsCount = 0

local transitionAlpha = 0
local transitionDir = 0 -- 1=fade in, -1=fade out
local transitionCallback = nil

function Game:startTransition(callback)
    transitionAlpha = 0
    transitionDir = 1
    transitionCallback = callback
end

function Game:update(dt)
    -- Handle unlock message timer
    if unlockMessage then
        unlockMessageTimer = unlockMessageTimer - dt
        if unlockMessageTimer <= 0 then
            unlockMessage = nil
        end
    end
    -- Pause and reset controls
    if love.keyboard.isDown('p') then paused = not paused end
    if love.keyboard.isDown('r') then self:startTransition(function() self:load() end) end
    if paused then return end

    -- Handle end of run (win or game over)
    if gameOver or win then
        local idx = currentCharacterIdx or 1
        if not characters[unlockedCharacters[idx]] then idx = 1 end
        local statsTable = {
            level = level,
            characterName = (selectedCharacter and selectedCharacter.name) ~= nil and (selectedCharacter and selectedCharacter.name)
                or ((Player.character and Player.character.name) ~= nil and (Player.character and Player.character.name))
                or (characters[unlockedCharacters[idx]].name),
            claimedPercent = math.floor(Grid:getClaimedPercent()*100),
            requiredPercent = math.floor(Grid.requiredClaimedPercent*100),
            areaCleared = (Grid.width-2)*(Grid.height-2),
            score = score,
            deaths = deaths,
            wins = wins,
            zonesClosed = zonesClosed or 0,
            abilitiesUsed = Player.abilitiesUsed or 0,
            bossesDefeated = bossesDefeated or 0,
            -- outcome is passed as a separate param to EndRun:enter
        }
        local currentOutcome = win and "win" or "gameOver"
        Gamestate.push(EndRun, currentOutcome, statsTable)
        return
    end

    -- Handle transition fade
    if transitionDir ~= 0 then
        transitionAlpha = transitionAlpha + transitionDir * dt * 2.2
        if transitionDir == 1 and transitionAlpha >= 1 then
            transitionAlpha = 1
            transitionDir = -1
            if transitionCallback then transitionCallback() end
        elseif transitionDir == -1 and transitionAlpha <= 0 then
            transitionAlpha = 0
            transitionDir = 0
            transitionCallback = nil
        end
    end

    -- Update game state
    elapsedTime = love.timer.getTime() - startTime
    Grid:update(dt)

    -- Update Freeze powerup effect
    if PowerUps.Freeze then
        PowerUps.Freeze:update(dt, self, Grid, Player, enemies)
    end

    -- FPS counter
    fpsTimer = fpsTimer + dt
    fpsCount = fpsCount + 1
    if fpsTimer >= 1 then
        fps = fpsCount
        fpsCount = 0
        fpsTimer = fpsTimer - 1
    end

    -- Stage-specific update hooks (onslaught, moving obstacles, custom win)
    local stageIdx = ((level-1) % #stages) + 1
    local stage = stages[stageIdx]
    if stage and stage.special then
        if Grid._onslaughtAddEnemy then
            Grid._onslaughtAddEnemy(dt, enemiesLib, Grid, enemies)
        end
        if Grid._moveObstacles then
            Grid._moveObstacles(dt, Grid)
        end
        if Game.checkWinCondition and Game.checkWinCondition() then
            win = true
            wins = wins + 1
        end
    end

    -- Realm-specific update (e.g., echo effect)
    if currentRealm and currentRealm.update then
        currentRealm:update(dt, Grid)
    end

    Player:update(dt, Grid)

    -- Enemy and player collision logic
    for _, enemy in ipairs(enemies) do
        if PowerUps.Freeze and PowerUps.Freeze:isEnemyFrozen(enemy) then
            -- Skip enemy update if frozen
        else
            enemy:update(dt, Grid, Player)
        end
        -- Check direct collision with player
        local p_node_i, p_node_j = Player.i, Player.j
        local cells_around_player_node = {
            {i = p_node_i - 1, j = p_node_j - 1}, {i = p_node_i, j = p_node_j - 1},
            {i = p_node_i - 1, j = p_node_j},     {i = p_node_i, j = p_node_j}
        }
        for _, cell_coord in ipairs(cells_around_player_node) do
            if Grid:isInside(cell_coord.i, cell_coord.j) then
                if enemy.i == cell_coord.i and enemy.j == cell_coord.j then
                    print("Enemy direct collision with player at node vicinity: PNode("..p_node_i..","..p_node_j..") ECell("..enemy.i..","..enemy.j..")")
                    gameOver = true; deaths = deaths + 1; break
                end
            end
        end
        if gameOver then break end
        -- Check collision with player's active trail
        if Player.isDrawing and #Player.trail >= 2 then
            for k = 1, #Player.trail - 1 do
                local n1 = Player.trail[k]
                local n2 = Player.trail[k+1]
                local ei, ej = enemy.i, enemy.j
                local hit_trail_segment = false
                if n1.i == n2.i then
                    if ej == math.min(n1.j, n2.j) then
                        if ei == n1.i - 1 or ei == n1.i then
                            hit_trail_segment = true
                        end
                    end
                elseif n1.j == n2.j then
                    if ei == math.min(n1.i, n2.i) then
                        if ej == n1.j - 1 or ej == n1.j then
                            hit_trail_segment = true
                        end
                    end
                end
                if hit_trail_segment then
                    print("Enemy collided with player trail segment between N("..n1.i..","..n1.j..") and N("..n2.i..","..n2.j.."). Enemy at C("..ei..","..ej..")")
                    if Player.fuseShieldActive then
                        -- Guardian's shield blocks death
                        Player.fuseShieldActive = false
                        Player.fuseTimer = 0
                    elseif not Player.isFuseActive then
                        -- Start fuse instead of instant death
                        Player.isFuseActive = true
                        Player.fuseTimer = Player.fuseDuration or 2.5
                        Player.burningTrail = {}
                        for _, node in ipairs(Player.trail) do table.insert(Player.burningTrail, {i=node.i, j=node.j}) end
                        -- Optional: play fuse sound/flash
                    end
                    break
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

local glowShader = love.graphics.newShader("shaders/glow.glsl")
glowShader:send("strength", 0.18)

function Game:draw()
    love.graphics.setShader(glowShader)
    Grid:draw()
    Player:draw(Grid)
    for _, enemy in ipairs(enemies) do
        enemy:draw(Grid)
    end
    -- Draw powerups on grid
    if Grid.powerups then
        for _, powerup in ipairs(Grid.powerups) do
            if not powerup.collected then
                powerup:draw(Grid)
            end
        end
    end
    love.graphics.setShader()
    self:drawUI()
    -- Draw transition overlay
    if transitionAlpha > 0 then
        love.graphics.setColor(0,0,0,transitionAlpha)
        love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1,1,1,1)
    end
    -- Remove UI overlays from here (jammed tint, floating text, ability bar, unlock message)
    -- ...rest of draw logic...
end

local showAbilities = false

-- In the drawUI or HUD logic, show the correct stage number and claimed percent for the current stage.
function Game:drawUI()
    local stageIdx = ((level-1) % #stages) + 1
    local stage = stages[stageIdx]
    local claimed = math.floor(Grid:getClaimedPercent()*100)
    local required = math.floor(Grid.requiredClaimedPercent*100)
    local stageText = string.format("Level %d  Claimed: %d/%d%%", level, claimed, required)
    love.graphics.setColor(0,0,0,0.7)
    love.graphics.rectangle('fill', love.graphics.getWidth()/2-110, 10, 220, 32, 8, 8)
    love.graphics.setColor(1,1,1,1)
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.printf(stageText, love.graphics.getWidth()/2-100, 16, 200, 'center')
    -- Show passive abilities for the current character only if toggled
    if showAbilities and Player.character and Player.character.getSkillDescription then
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.setColor(0.1,0.1,0.1,0.7)
        love.graphics.rectangle('fill', 10, 10, 320, 60, 8, 8)
        love.graphics.setColor(0.7,1,0.7,1)
        love.graphics.printf("Passive Abilities:", 20, 16, 300, 'left')
        love.graphics.setColor(1,1,1,1)
        love.graphics.printf(Player.character:getSkillDescription(), 20, 36, 300, 'left')
    end
    -- Debug overlay: FPS and zone state
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.setColor(0.2,1,0.2,0.7)
    love.graphics.print('FPS: '..tostring(fps), 10, love.graphics.getHeight()-24)
    love.graphics.setColor(0.2,0.7,1,0.7)
    love.graphics.print('Claimed: '..math.floor(Grid:getClaimedPercent()*100)..'%', 90, love.graphics.getHeight()-24)
    love.graphics.setColor(1,1,1,1)
    -- ...existing code for ability bar, overlays, etc...
    -- Show hint for toggling abilities
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.setColor(1,1,1,0.7)
    love.graphics.printf("Press TAB or H to show/hide abilities", 12, 76, 300, 'left')
end

function Game:keypressed(key)
    if key == 'p' then paused = not paused end
    if key == 'r' then self:startTransition(function() self:load() end) end
    -- Quick restart: Enter/Space on end screen
    if (gameOver or win) and (key == 'return' or key == 'space') then
        self:startTransition(function()
            level = 1
            deaths = 0
            wins = 0
            score = 0
            zonesClosed = 0
            bossesDefeated = 0
            Player.abilitiesUsed = 0
            self:load()
        end)
    end
    if key == 'tab' or key == 'h' then
        showAbilities = not showAbilities
    end
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

-- In Player:update(dt, Grid):
-- If Player.isJammed, reduce speed
if Player.isJammed then
    Player.speedModifier = 0.6
elseif Player.speedModifier and Player.speedModifier ~= 1 then
    Player.speedModifier = 1
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

-- Define PowerUps table at the top of game.lua so it is available for stage powerup spawning.
local Freeze = require('src.powerups.freeze')
local PowerUps = { SpeedBoost = require('src.powerups.speed_boost'), Freeze = Freeze }

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

_G.PowerUps = PowerUps

return Game
