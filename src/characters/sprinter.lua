local Sprinter = {}
Sprinter.name = "Sprinter"
Sprinter.description = "Moves very fast, but trail is fragile."
Sprinter.color = {1, 0.5, 0.2}
Sprinter.trailColor = {1, 0.7, 0.2}
Sprinter.speed = 3.2
Sprinter.trailLength = 14
Sprinter.passives = {
    "Passive: +50% movement speed.",
    "Trail disappears quickly if not closed."
}
return Sprinter
