local love = require "love"
local Gamestate = require 'hump.gamestate'
local EndRun = {}

local outcomeMessage = ""
local stats = {}
local fontLarge = nil
local fontMedium = nil
local fontSmall = nil

function EndRun:init()
    -- Initialize fonts if not already done (or do it in :enter if preferred)
    fontLarge = love.graphics.newFont(24)
    fontMedium = love.graphics.newFont(16)
    fontSmall = love.graphics.newFont(14)
end

-- Called when switching to this state
function EndRun:enter(actualOutcome, actualStatsTable) -- Parameter names are as originally intended semantically
    -- However, logs show actualOutcome is the table, and actualStatsTable is the string.
    -- Let's use them according to what they actually are.

    local receivedOutcomeString, receivedStatsTable
    if type(actualOutcome) == "string" and type(actualStatsTable) == "table" then
        receivedOutcomeString = actualOutcome
        receivedStatsTable = actualStatsTable
    elseif type(actualOutcome) == "table" and type(actualStatsTable) == "string" then
        -- Old bugged order
        receivedOutcomeString = actualStatsTable
        receivedStatsTable = actualOutcome
    else
        receivedOutcomeString = tostring(actualOutcome)
        receivedStatsTable = actualStatsTable or {}
    end

    print("EndRun:enter - receivedStatsTable (originally actualOutcome): " .. tostring(receivedStatsTable) .. ", type: " .. type(receivedStatsTable)) -- DEBUG
    print("EndRun:enter - receivedOutcomeString (originally actualStatsTable) type: " .. type(receivedOutcomeString)) -- DEBUG

    outcomeMessage = (receivedOutcomeString == "win") and "LEVEL CLEARED!" or "GAME OVER"
    stats = receivedStatsTable or {} -- Assign the table to the upvalue 'stats'
    stats.outcome = receivedOutcomeString -- Store the outcome string in the table's 'outcome' field

    -- Ensure fonts are loaded
    if not fontLarge then
        self:init()
    end
end

function EndRun:update(dt)
    -- Potentially handle a timer for auto-transition or animations later
end

function EndRun:draw()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()

    -- Background overlay (optional, to dim the game behind)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Stats Box
    local boxW, boxH = 320, 200 -- Adjusted size
    local boxX, boxY = (screenW - boxW) / 2, (screenH - boxH) / 2

    love.graphics.setColor(0.2, 0.2, 0.25, 0.9) -- Darker background for stats
    love.graphics.rectangle('fill', boxX, boxY, boxW, boxH, 15, 15)
    
    -- Outcome Message
    love.graphics.setFont(fontLarge)
    if stats.outcome == "win" then
        love.graphics.setColor(0.2, 1, 0.2, 0.95)
    else
        love.graphics.setColor(1, 0.2, 0.2, 0.95)
    end
    love.graphics.printf(outcomeMessage, 0, boxY - 60, screenW, 'center')

    -- Stats Text
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.95, 0.95, 0.95)
    
    local statText = string.format(
        "Level: %s\nCharacter: %s\nClaimed: %s/%s%%\nArea Cleared: %s\nFinal Score: %s\nDeaths: %s | Wins: %s",
        stats.level or "N/A",
        stats.characterName or "N/A",
        stats.claimedPercent or "N/A",
        stats.requiredPercent or "N/A",
        stats.areaCleared or "N/A",
        stats.score or "N/A",
        stats.deaths or "N/A",
        stats.wins or "N/A"
    )
    love.graphics.printf(statText, boxX + 20, boxY + 20, boxW - 40, 'left')

    -- Continue Prompt
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(0.9, 0.9, 0.9, 0.9)
    local continuePrompt = (stats.outcome == "win") and "Press any key for NEXT LEVEL" or "Press any key to RESTART"
    love.graphics.printf(continuePrompt, 0, boxY + boxH + 30, screenW, 'center')

    love.graphics.setColor(1,1,1) -- Reset color
end

function EndRun:keypressed(key)
    print("EndRun:keypressed - About to pop. stats.outcome type: " .. type(stats.outcome) .. ", value: " .. tostring(stats.outcome)) -- DEBUG
    -- When a key is pressed, EndRun simply pops itself from the Gamestate stack.
    -- It passes its stored 'stats.outcome' back to the previous state (which should be Game).
    Gamestate.pop(stats.outcome) 
end

function EndRun:leave()
    -- Cleanup if needed
    outcomeMessage = ""
    stats = {}
end

return EndRun
