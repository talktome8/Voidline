-- Voidline main.lua
local Gamestate = require 'hump.gamestate'
local love = require "love" -- Ensure love is required at the top

-- Declare module variables; require them inside love.load
local Menu
local Game
local EndRun

local logFile = nil -- For writing print output to a file

_G.love = _G.love or {} -- Ensure the global love table exists for defining functions

function _G.love.load()
    -- Attempt to open output.txt for logging in append mode
    logFile = io.open("output.txt", "a") -- Changed "w" to "a"
    
    local originalPrint = print -- Store original print
    
    if not logFile then
        originalPrint("Error: Could not open output.txt for writing! Output will only go to console.")
    else
        -- Add a separator for new game session using actual newline characters
        logFile:write("\\n---------------- NEW GAME SESSION: " .. os.date() .. " ----------------\\n")
        logFile:flush()

        -- Redefine global print function
        _G.print = function(...)
            local args = {...}
            local s_for_file = ""
            for i, v in ipairs(args) do
                s_for_file = s_for_file .. tostring(v)
                if i < #args then
                    s_for_file = s_for_file .. "\t"
                end
            end
            logFile:write(s_for_file .. "\n")
            logFile:flush()
            
            -- Call original print with all arguments
            if #args == 0 then
                originalPrint()
            elseif #args == 1 then
                originalPrint(args[1])
            elseif #args == 2 then
                originalPrint(args[1], args[2])
            elseif #args == 3 then
                originalPrint(args[1], args[2], args[3])
            else
                -- For more than 3 args, convert to string
                originalPrint(s_for_file)
            end
        end
    end

    -- Load all dynamic modules first, as requireAll needs love.filesystem
    require 'src.init'
    
    -- Load sound system
    local Sound = require 'src.utils.sound'
    Sound.load()

    -- Now require other top-level modules that might depend on components loaded by src.init
    Menu = require 'src.ui.menu'
    Game = require 'src.game'
    EndRun = require 'src.ui.endrun'

    do local ok, Config = pcall(require, 'src.config'); if ok and Config.debug and Config.debug.enabled then print('Voidline initialized') end end
    Gamestate.registerEvents()
    Gamestate.switch(Menu)
end

function _G.love.quit()
    if logFile then
    local ok, Config = pcall(require, 'src.config')
    if ok and Config.debug and Config.debug.enabled then print("Closing log file.") end -- This will also go to the log file itself before closing
        logFile:close()
        logFile = nil
    end
    -- If hump.gamestate handles love.quit or if there was a custom one:
    -- local success, err = pcall(function() Gamestate.quit() end) -- Example if Gamestate has a quit
    -- if not success then print("Error during Gamestate.quit:", err) end
    return false -- Standard Love2D quit behavior
end

-- This file is not needed. The real entry point is main.lua at the root. Please delete this file.
