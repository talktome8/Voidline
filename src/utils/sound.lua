-- src/utils/sound.lua
local Sound = {}
local sounds = {}

local function loadSoundSafe(path, type)
    local success, sound = pcall(love.audio.newSource, path, type or "static")
    if success then
        return sound
    else
    if not Sound._missing then Sound._missing = {} end
    table.insert(Sound._missing, path)
        return nil
    end
end

function Sound.load()
    sounds.zone = loadSoundSafe("assets/sounds/zone_close.wav")
    sounds.death = loadSoundSafe("assets/sounds/death.wav")
    sounds.ability = loadSoundSafe("assets/sounds/ability.wav")
    sounds.boss = loadSoundSafe("assets/sounds/boss.wav")
    if Sound._missing and #Sound._missing > 0 then
        print("Warning: Some sounds missing (", #Sound._missing, ") - running with silent fallbacks")
        for _,p in ipairs(Sound._missing) do
            -- Uncomment for detailed list
            -- print("  missing:", p)
        end
    end
end

function Sound.play(name)
    if sounds[name] then
        sounds[name]:stop()
        sounds[name]:play()
    end
end

return Sound
