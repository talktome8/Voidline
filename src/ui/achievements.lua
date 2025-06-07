-- Achievements and Leaderboard UI
local Achievements = {}

Achievements.personal = { zones = 0, deaths = 0, wins = 0, best = 0 }
Achievements.global = { best = 0, players = 1 }
Achievements.list = {
    { key = "close90", label = "Close 90% in a single run", unlocked = false },
    { key = "defeatBoss", label = "Defeat a boss stage", unlocked = false },
    { key = "allChars", label = "Win with every character", unlocked = false },
    { key = "noDeath", label = "Win a stage without dying", unlocked = false },
    { key = "zoneStreak", label = "Close 5 zones in 30 seconds", unlocked = false },
}

function Achievements:unlock(key)
    for _, a in ipairs(self.list) do
        if a.key == key then a.unlocked = true end
    end
end

function Achievements:draw(x, y, w, h)
    love.graphics.setColor(0.95,0.95,0.95,0.8)
    love.graphics.rectangle('fill', x, y, w, h, 10, 10)
    love.graphics.setColor(0.1,0.1,0.1)
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.printf('Achievements', x, y+8, w, 'center')
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.printf('Personal:', x+10, y+32, w-20, 'left')
    love.graphics.printf('Zones Closed: '..self.personal.zones, x+20, y+52, w-40, 'left')
    love.graphics.printf('Deaths: '..self.personal.deaths, x+20, y+72, w-40, 'left')
    love.graphics.printf('Wins: '..self.personal.wins, x+20, y+92, w-40, 'left')
    love.graphics.printf('Best %: '..self.personal.best, x+20, y+112, w-40, 'left')
    love.graphics.printf('Global:', x+10, y+142, w-20, 'left')
    love.graphics.printf('Best %: '..self.global.best, x+20, y+162, w-40, 'left')
    love.graphics.printf('Players: '..self.global.players, x+20, y+182, w-40, 'left')
    -- Draw achievement list
    love.graphics.setFont(love.graphics.newFont(12))
    local ay = y+210
    for _, a in ipairs(self.list) do
        love.graphics.setColor(a.unlocked and {0.2,0.8,0.2,1} or {0.5,0.5,0.5,0.7})
        love.graphics.printf((a.unlocked and '✔ ' or '✖ ')..a.label, x+20, ay, w-40, 'left')
        ay = ay + 20
    end
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.setColor(1,1,1)
end

return Achievements
