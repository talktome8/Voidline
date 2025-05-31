local Scorer = {}
Scorer.name = "Scorer"
Scorer.description = "Gets double points for closing large areas."
Scorer.color = {1, 1, 0.2}
Scorer.trailColor = {1, 1, 0.6}
Scorer.speed = 2.0
Scorer.trailLength = 18
Scorer.passives = {
    "Double score for large zone closures",
    "Balanced stats"
}
return Scorer
