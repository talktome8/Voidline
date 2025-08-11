local love = require "love"
local Gamestate = require 'hump.gamestate'
local EndRun = {}
-- local Game = require('src.game') -- REMOVE THIS LINE TO BREAK THE CIRCULAR DEPENDENCY
local stages = require('src.stages.init')

local font_title = love.graphics.newFont(36)
local font_stats = love.graphics.newFont(18)
local font_footer = love.graphics.newFont(16)

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
        -- Handle parameter order variation
        receivedOutcomeString = actualStatsTable
        receivedStatsTable = actualOutcome
    else
        receivedOutcomeString = tostring(actualOutcome)
        receivedStatsTable = actualStatsTable or {}
    end

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
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    -- Animated gradient background for end screen
    for i=0, wh, 2 do
        local t = i/wh
        love.graphics.setColor(0.18*(1-t)+0.32*t, 0.22*(1-t)+0.36*t, 0.28*(1-t)+0.44*t + 0.04*math.sin(love.timer.getTime()*0.7+i*0.01), 1)
        love.graphics.rectangle('fill', 0, i, ww, 2)
        if i%18==0 then
            love.graphics.setColor(0.12,0.18,0.28,0.10+0.08*math.abs(math.sin(love.timer.getTime()*0.5+i*0.02)))
            for x=0,ww,40 do
                love.graphics.circle('fill', x, i, 10+2*math.sin(love.timer.getTime()+x*0.01+i*0.01))
            end
        end
    end
    -- Title with animated shadow
    love.graphics.setFont(font_title)
    for dx=-3,3 do for dy=-3,3 do
        if dx~=0 or dy~=0 then
            love.graphics.setColor(0,0,0,0.18-0.02*math.abs(dx*dy))
            love.graphics.printf(outcomeMessage, dx, 80+dy, ww, 'center')
        end
    end end
    love.graphics.setColor(1,1,1)
    love.graphics.printf(outcomeMessage, 0, 80, ww, 'center')
    -- Stats box with animated border
    local boxY = 160
    local pulse = 0.95+0.05*math.sin(love.timer.getTime()*3)
    love.graphics.setColor(0.2*pulse,0.7*pulse,1*pulse, 0.18+0.08*pulse)
    love.graphics.rectangle('fill', ww/2-220, boxY, 440, 320, 24, 24)
    love.graphics.setColor(1, 0.85, 0.2, 0.9)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle('line', ww/2-220, boxY, 440, 320, 24, 24)
    love.graphics.setLineWidth(1)
    -- Add animated stats icon
    local statsPulse = 0.9+0.1*math.sin(love.timer.getTime()*2.7)
    love.graphics.setColor(0.2*statsPulse,1*statsPulse,0.7*statsPulse,0.7)
    love.graphics.circle('fill', ww/2, boxY+40, 18+4*statsPulse, 36)
    love.graphics.setColor(1,1,1,0.18)
    love.graphics.circle('line', ww/2, boxY+40, 22+5*statsPulse, 36)
    -- Draw trophy or skull icon
    if stats.outcome == 'win' then
        love.graphics.setColor(1, 0.85, 0.2, 0.8)
        love.graphics.circle('fill', ww/2, boxY+40, 22, 32)
        love.graphics.setColor(0.7,0.5,0.1,1)
        love.graphics.rectangle('fill', ww/2-10, boxY+62, 20, 14, 5, 5)
    else
        love.graphics.setColor(0.8,0.2,0.2,0.8)
        love.graphics.circle('fill', ww/2, boxY+40, 22, 32)
        love.graphics.setColor(0.2,0.2,0.2,1)
        love.graphics.rectangle('fill', ww/2-10, boxY+62, 20, 14, 5, 5)
    end
    love.graphics.setColor(1,1,1,1)
    -- Stats text
    love.graphics.setFont(font_stats)
    -- Show both stage and cumulative stats at end of run
    local statsY = boxY+90
    local statsList = {}
    if stats.level then table.insert(statsList, 'Level: '..stats.level) end
    if stats.characterName then table.insert(statsList, 'Character: '..stats.characterName) end
    if stats.claimedPercent and stats.requiredPercent then table.insert(statsList, 'Claimed: '..stats.claimedPercent..'/'..stats.requiredPercent..'%') end
    if stats.score then table.insert(statsList, 'Score (Stage): '..stats.score) end
    if stats.zonesClosed then table.insert(statsList, 'Zones Closed (Stage): '..stats.zonesClosed) end
    if stats.abilitiesUsed then table.insert(statsList, 'Abilities Used (Stage): '..stats.abilitiesUsed) end
    if stats.bossesDefeated then table.insert(statsList, 'Bosses Defeated (Total): '..stats.bossesDefeated) end
    if stats.deaths then table.insert(statsList, 'Total Deaths: '..stats.deaths) end
    if stats.wins then table.insert(statsList, 'Total Wins: '..stats.wins) end
    -- Cumulative stats (if available)
    if stats.cumulative then
        table.insert(statsList, '---')
        table.insert(statsList, 'Cumulative Stats:')
        if stats.cumulative.totalScore then table.insert(statsList, 'Total Score: '..stats.cumulative.totalScore) end
        if stats.cumulative.totalZonesClosed then table.insert(statsList, 'Total Zones Closed: '..stats.cumulative.totalZonesClosed) end
        if stats.cumulative.totalAbilitiesUsed then table.insert(statsList, 'Total Abilities Used: '..stats.cumulative.totalAbilitiesUsed) end
        if stats.cumulative.totalDeaths then table.insert(statsList, 'Total Deaths: '..stats.cumulative.totalDeaths) end
        if stats.cumulative.totalWins then table.insert(statsList, 'Total Wins: '..stats.cumulative.totalWins) end
        -- Show any other stats
        for k, v in pairs(stats.cumulative) do
            if not (k == 'totalScore' or k == 'totalZonesClosed' or k == 'totalAbilitiesUsed' or k == 'totalDeaths' or k == 'totalWins') then
                table.insert(statsList, k..': '..v)
            end
        end
    end
    if stats.outcome == 'win' then
        table.insert(statsList, 'Great job! Next level unlocked!')
    elseif stats.outcome == 'gameOver' then
        table.insert(statsList, 'Try again to beat your best!')
    end
    for i, stat in ipairs(statsList) do
        love.graphics.setColor(0.8,0.9,1,0.92)
        love.graphics.printf(stat, ww/2-200, statsY+(i-1)*32, 400, 'center')
    end
    -- Footer
    love.graphics.setFont(font_footer)
    love.graphics.setColor(0.7,0.9,1,0.7)
    love.graphics.printf('Press Enter/Space to continue', 0, wh-40, ww, 'center')
end

function EndRun:keypressed(key)
    -- When a key is pressed, EndRun simply pops itself from the Gamestate stack.
    -- It passes its stored 'stats.outcome' back to the previous state (which should be Game).
    -- Fix: pass also the stages table if needed
    Gamestate.pop(stats.outcome, stages)
end

function EndRun:leave()
    -- Cleanup if needed
    outcomeMessage = ""
    stats = {}
end

return EndRun
