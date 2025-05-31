local Architect = {}

Architect.name = "Architect"
Architect.description = "Master of control. Can briefly freeze all enemies when closing a zone."
Architect.color = {0.2, 0.6, 1} -- blue
Architect.trailColor = {1, 0.8, 0.2} -- yellow
Architect.speed = 2.0
Architect.trailLength = 20
Architect.passives = {
    "Freeze all enemies for 1s after closing a zone",
    "Standard speed and trail"
}

function Architect:load()
end

function Architect:update(dt)
end

function Architect:draw()
end

return Architect
