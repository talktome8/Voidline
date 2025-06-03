local Scorer = {}
Scorer.name = "Scorer"
Scorer.description = "Gets double points for closing large areas."
Scorer.color = {1, 1, 0.3}
Scorer.trailColor = {1, 1, 0.5}
Scorer.speed = 2.0
Scorer.trailLength = 16
Scorer.passives = {
    "Passive: Double score for large zone closures.",
    "Normal speed, normal trail."
}
return Scorer
