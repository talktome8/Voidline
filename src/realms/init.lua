local love = require "love"

local loadedRealmsArray = {} 
local initialized = false

local function initializeRealms()
    if initialized then return end

    -- Ensure love.filesystem is available (it should be by the time this is required)
    if not love or not love.filesystem then
        print("ERROR: love.filesystem not available in realms/init.lua yet.")
        return
    end

    local realmFiles = love.filesystem.getDirectoryItems("src/realms")
    for _, file in ipairs(realmFiles) do
        local name = file:match("(.+)%.lua")
        if name and name ~= "init" then
            -- Assuming the require path is relative to the project root
            -- or that the package path is configured for this structure.
            local realmModule = require("src.realms." .. name)
            if realmModule then
                table.insert(loadedRealmsArray, realmModule)
            else
                print("Warning: Failed to load realm module: src.realms." .. name)
            end
        end
    end
    initialized = true
    -- print("Realms initialized. Count: " .. #loadedRealmsArray) -- Debug print
end

-- Call initializeRealms when the module is required, so the array is populated.
initializeRealms()

local VoidHatchery = require('src.realms.void_hatchery')
local EchoLab = require('src.realms.echo_lab')
local PulseMines = require('src.realms.pulse_mines')

-- Instead of returning a table with named realms, return the loadedRealmsArray for dynamic realm loading
return loadedRealmsArray
