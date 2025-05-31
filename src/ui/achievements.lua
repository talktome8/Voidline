-- Achievements and Leaderboard UI
local Achievements = {}

Achievements.personal = { zones = 0, deaths = 0, wins = 0, best = 0 }
Achievements.global = { best = 0, players = 1 }

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
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.setColor(1,1,1)
end

return Achievements
