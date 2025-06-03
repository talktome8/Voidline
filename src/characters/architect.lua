local Architect = {}

Architect.name = "Architect"
Architect.description = "Area closure is easier. Trail persists if you stop. Large zone bonus." -- Updated
Architect.color = {0.2, 0.7, 1} -- blue
Architect.trailColor = {0.2, 0.9, 1} -- yellow

Architect.speed = 1.7 -- Slightly slower, as "בונה לאט"
Architect.trailLength = 20 -- Standard, can be adjusted if needed

-- New properties for passives
Architect.trailPersistDuration = 1.5 -- seconds, "קו ה־trail לא נעלם במשך 2 שניות"
Architect.largeZoneBonusMultiplier = 2 -- "שטחים גדולים מקבלים ניקוד כפול"
Architect.loopClosureBonusPercent = 0.01 -- 1% bonus, "תוספת קטנה לאחוז הסגירה"
Architect.largeZoneThreshold = 50 -- Example threshold for 'large zone', in cells
Architect.freezeDuration = 1 -- seconds, for enemy freeze passive
Architect.fuseDuration = 5 -- פיוז רגיל

Architect.passives = {
    "Passive: Large zone bonus (more points for big areas)",
    "Trail persists for a while if you stop moving.",
    "Normal fuse: 5 seconds to return to border.",
    "Area closure is easier (less strict validation)."
}

function Architect:load()
    -- any specific load-time setup for Architect
end

function Architect:update(dt)
    -- any specific update logic for Architect (e.g., managing internal timers for abilities)
end

function Architect:draw()
    -- any specific drawing for Architect (e.g., visual cues for abilities)
end

function Architect:getSkillDescription()
    return table.concat(self.passives, "\n")
end

return Architect
