local Sprinter = {}
Sprinter.name = "Sprinter"
Sprinter.description = "Moves very fast, but trail is fragile."
Sprinter.color = {1, 0.4, 0.2}
Sprinter.trailColor = {1, 0.7, 0.4}
Sprinter.speed = 3.0
Sprinter.trailLength = 10
Sprinter.passives = {
    "+50% movement speed",
    "Trail disappears quickly if not closed"
}
return Sprinter
