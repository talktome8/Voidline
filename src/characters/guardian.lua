local Guardian = {}
Guardian.name = "Guardian"
Guardian.description = "Slow, but trail is invulnerable to enemies."
Guardian.color = {0.2, 0.7, 1}
Guardian.trailColor = {0.4, 0.9, 1}
Guardian.speed = 1.5
Guardian.trailLength = 30
Guardian.passives = {
    "Trail cannot be erased by enemies",
    "+30% trail length"
}
return Guardian
