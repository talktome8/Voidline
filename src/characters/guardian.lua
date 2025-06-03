local Guardian = {}
Guardian.name = "Guardian"
Guardian.description = "פיוז איטי, יכולת לנטרל פיוז פעם אחת"
Guardian.speed = 1.3
Guardian.trailLength = 18
Guardian.color = {0.2, 0.7, 1}
Guardian.trailColor = {0.2, 0.9, 1}
Guardian.passives = {
    "Passive: Can defuse fuse once per run (press D)",
    "Slow fuse: 8 seconds to return to border.",
    "Immune to first GuardianBreaker attack.",
    "Trail is more stable (less likely to disappear)."
}

function Guardian:getSkillDescription()
    return table.concat(self.passives, "\n")
end

return Guardian
