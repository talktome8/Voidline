local Architect = {}

Architect.name = "Architect"
Architect.description = "Builds slowly but closes huge areas. Master of zone control." -- Updated
Architect.color = {0.2, 0.6, 1} -- blue
Architect.trailColor = {1, 0.8, 0.2} -- yellow

Architect.speed = 1.8 -- Slightly slower, as "בונה לאט"
Architect.trailLength = 20 -- Standard, can be adjusted if needed

-- New properties for passives
Architect.trailPersistDuration = 2 -- seconds, "קו ה־trail לא נעלם במשך 2 שניות"
Architect.largeZoneBonusMultiplier = 2 -- "שטחים גדולים מקבלים ניקוד כפול"
Architect.loopClosureBonusPercent = 0.01 -- 1% bonus, "תוספת קטנה לאחוז הסגירה"
Architect.largeZoneThreshold = 50 -- Example threshold for 'large zone', in cells
Architect.freezeDuration = 1 -- seconds, for enemy freeze passive

Architect.passives = {
    "Large zones grant double points.",
    "Trail persists for 2 seconds after leaving it.",
    "Gain a small bonus to claimed area per loop closed.",
    "Freezes enemies for 1s after closing a zone." -- Existing, rephrased
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

return Architect
