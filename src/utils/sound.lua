-- src/utils/sound.lua
local Sound = {}
local sounds = {}

function Sound.load()
    sounds.zone = love.audio.newSource("assets/sounds/zone_close.wav", "static")
    sounds.death = love.audio.newSource("assets/sounds/death.wav", "static")
    sounds.ability = love.audio.newSource("assets/sounds/ability.wav", "static")
    sounds.boss = love.audio.newSource("assets/sounds/boss.wav", "static")
end

function Sound.play(name)
    if sounds[name] then
        sounds[name]:stop()
        sounds[name]:play()
    end
end

return Sound
