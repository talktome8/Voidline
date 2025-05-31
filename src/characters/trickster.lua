local Trickster = {}

Trickster.name = "Trickster"
Trickster.description = "Can swap places with a random enemy every 10s. Unpredictable!"
Trickster.color = {0.9, 0.3, 0.7} -- magenta
Trickster.trailColor = {1, 0.6, 0.4} -- orange
Trickster.speed = 2.3
Trickster.trailLength = 15
Trickster.passives = {
    "Swaps position with a random enemy every 10s",
    "Unpredictable movement"
}

function Trickster:load()
end

function Trickster:update(dt)
end

function Trickster:draw()
end

return Trickster
