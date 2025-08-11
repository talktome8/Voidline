-- Achievements and Leaderboard UI - Steam Ready
local Achievements = {}

Achievements.personal = { 
    zones = 0, 
    deaths = 0, 
    wins = 0, 
    best = 0,
    shapesDrawn = 0,
    perfectShapes = 0,
    abilitiesUsed = 0,
    enemiesDefeated = 0,
    playTime = 0,
    currentStreak = 0,
    bestStreak = 0
}

Achievements.global = { 
    best = 0, 
    players = 1,
    totalShapes = 0,
    totalZones = 0
}

-- COMPREHENSIVE ACHIEVEMENT SYSTEM - Steam Ready
Achievements.list = {
    -- Tutorial & Basic
    { key = "firstSteps", label = "First Steps - Complete your first level", unlocked = false, steamId = 1 },
    { key = "shapeMaster", label = "Shape Master - Draw 10 shapes accurately", unlocked = false, steamId = 2 },
    { key = "territoryKing", label = "Territory King - Capture 75% of a level", unlocked = false, steamId = 3 },
    
    -- Skill Based
    { key = "perfectionist", label = "Perfectionist - Draw 5 perfect shapes (95%+ accuracy)", unlocked = false, steamId = 4 },
    { key = "speedDemon", label = "Speed Demon - Complete a level in under 2 minutes", unlocked = false, steamId = 5 },
    { key = "survival", label = "Survivor - Complete 5 levels without dying", unlocked = false, steamId = 6 },
    { key = "zoneStreak", label = "Zone Streak - Close 5 zones in 30 seconds", unlocked = false, steamId = 7 },
    
    -- Advanced
    { key = "shapeVariety", label = "Shape Variety - Draw all basic shapes (triangle, square, circle)", unlocked = false, steamId = 8 },
    { key = "abilityMaster", label = "Ability Master - Use abilities 25 times", unlocked = false, steamId = 9 },
    { key = "enemyEvader", label = "Enemy Evader - Avoid 100 enemy contacts", unlocked = false, steamId = 10 },
    { key = "precisionArtist", label = "Precision Artist - Draw 50 shapes with 80%+ accuracy", unlocked = false, steamId = 11 },
    
    -- Challenge
    { key = "defeatBoss", label = "Boss Slayer - Defeat a boss enemy", unlocked = false, steamId = 12 },
    { key = "allChars", label = "Character Master - Win with every character", unlocked = false, steamId = 13 },
    { key = "flawlessVictory", label = "Flawless Victory - Complete level 10 without losing a life", unlocked = false, steamId = 14 },
    { key = "shapeSynergy", label = "Shape Synergy - Draw 3 perfect shapes in one level", unlocked = false, steamId = 15 },
    
    -- Mastery
    { key = "grandMaster", label = "Grand Master - Reach level 20", unlocked = false, steamId = 16 },
    { key = "dedicatedPlayer", label = "Dedicated Player - Play for 5 hours total", unlocked = false, steamId = 17 },
    { key = "territoryLord", label = "Territory Lord - Capture 1000 zones total", unlocked = false, steamId = 18 },
    { key = "artisticGenius", label = "Artistic Genius - Draw 500 shapes total", unlocked = false, steamId = 19 },
    
    -- Ultra Rare
    { key = "legendary", label = "Legendary - Achieve 100% territory and shape accuracy in one level", unlocked = false, steamId = 20 },
}

-- Character tracking for "all characters" achievement
Achievements.charactersWon = {
    Architect = false,
    Trickster = false,
    Echo = false,
    Sprinter = false,
    Guardian = false,
    Scorer = false
}

-- Shape variety tracking
Achievements.shapesDrawn = {
    triangle = false,
    square = false,
    circle = false,
    heart = false,
    star = false
}

function Achievements:unlock(key, showNotification)
    for _, a in ipairs(self.list) do
        if a.key == key and not a.unlocked then
            a.unlocked = true
            print("🏆 ACHIEVEMENT UNLOCKED:", a.label)
            
            -- Steam integration placeholder
            if a.steamId then
                self:triggerSteamAchievement(a.steamId)
            end
            
            -- Show in-game notification
            if showNotification ~= false then
                self:showAchievementNotification(a.label)
            end
            return true
        end
    end
    return false
end

-- Steam integration placeholder
function Achievements:triggerSteamAchievement(steamId)
    -- Placeholder for Steam API integration
    print("🎮 Steam Achievement ID", steamId, "would be unlocked here")
    -- In real implementation:
    -- if steamworks then steamworks.userStats.setAchievement("achievement_" .. steamId) end
end

-- Achievement notification system
Achievements.notifications = {}
function Achievements:showAchievementNotification(label)
    table.insert(self.notifications, {
        text = "🏆 " .. label,
        timer = 4.0,
        alpha = 1.0
    })
end

function Achievements:updateNotifications(dt)
    for i = #self.notifications, 1, -1 do
        local notif = self.notifications[i]
        notif.timer = notif.timer - dt
        
        if notif.timer <= 1.0 then
            notif.alpha = notif.timer / 1.0  -- Fade out in last second
        end
        
        if notif.timer <= 0 then
            table.remove(self.notifications, i)
        end
    end
end

function Achievements:drawNotifications()
    local y = 100
    for _, notif in ipairs(self.notifications) do
        love.graphics.setColor(0.1, 0.7, 0.1, notif.alpha * 0.9)
        love.graphics.rectangle('fill', 50, y, 300, 40, 8, 8)
        love.graphics.setColor(0.2, 1.0, 0.2, notif.alpha)
        love.graphics.rectangle('line', 50, y, 300, 40, 8, 8)
        
        love.graphics.setColor(1, 1, 1, notif.alpha)
        love.graphics.printf(notif.text, 60, y + 12, 280, 'left')
        
        y = y + 50
    end
end

-- Check and trigger achievements based on game events
function Achievements:checkAchievements(gameData)
    local stats = gameData or {}
    
    -- Update personal stats
    if stats.levelCompleted then self.personal.wins = self.personal.wins + 1 end
    if stats.playerDied then 
        self.personal.deaths = self.personal.deaths + 1
        self.personal.currentStreak = 0
    end
    if stats.zonesClosed then self.personal.zones = self.personal.zones + stats.zonesClosed end
    if stats.territoryPercent then self.personal.best = math.max(self.personal.best, stats.territoryPercent) end
    if stats.shapesDrawn then self.personal.shapesDrawn = self.personal.shapesDrawn + stats.shapesDrawn end
    if stats.perfectShapes then self.personal.perfectShapes = self.personal.perfectShapes + stats.perfectShapes end
    if stats.abilitiesUsed then self.personal.abilitiesUsed = self.personal.abilitiesUsed + stats.abilitiesUsed end
    if stats.playTime then self.personal.playTime = self.personal.playTime + stats.playTime end
    
    -- Achievement checks
    if self.personal.shapesDrawn >= 10 then self:unlock("shapeMaster") end
    if self.personal.perfectShapes >= 5 then self:unlock("perfectionist") end
    if self.personal.abilitiesUsed >= 25 then self:unlock("abilityMaster") end
    if self.personal.shapesDrawn >= 50 then self:unlock("precisionArtist") end
    if self.personal.wins >= 1 then self:unlock("firstSteps") end
    if self.personal.zones >= 1000 then self:unlock("territoryLord") end
    if self.personal.shapesDrawn >= 500 then self:unlock("artisticGenius") end
    if self.personal.playTime >= 18000 then self:unlock("dedicatedPlayer") end -- 5 hours
    
    -- Level-specific achievements
    if stats.level and stats.level >= 20 then self:unlock("grandMaster") end
    if stats.level and stats.level >= 10 and stats.livesRemaining and stats.livesRemaining >= 3 then 
        self:unlock("flawlessVictory") 
    end
    
    -- Territory achievements
    if stats.territoryPercent and stats.territoryPercent >= 75 then self:unlock("territoryKing") end
    if stats.territoryPercent and stats.territoryPercent >= 100 and stats.shapeAccuracy and stats.shapeAccuracy >= 100 then
        self:unlock("legendary")
    end
    
    -- Character achievement
    if stats.character and stats.levelCompleted then
        self.charactersWon[stats.character] = true
        local allWon = true
        for _, won in pairs(self.charactersWon) do
            if not won then allWon = false; break end
        end
        if allWon then self:unlock("allChars") end
    end
    
    -- Shape variety
    if stats.shapeType then
        self.shapesDrawn[stats.shapeType] = true
        if self.shapesDrawn.triangle and self.shapesDrawn.square and self.shapesDrawn.circle then
            self:unlock("shapeVariety")
        end
    end
    
    -- Multiple shapes in one level
    if stats.perfectShapesThisLevel and stats.perfectShapesThisLevel >= 3 then
        self:unlock("shapeSynergy")
    end
end

-- Save achievements to file (Steam will handle this in real implementation)
function Achievements:save()
    local saveData = {
        personal = self.personal,
        global = self.global,
        unlockedAchievements = {},
        charactersWon = self.charactersWon,
        shapesDrawn = self.shapesDrawn
    }
    
    for _, achievement in ipairs(self.list) do
        if achievement.unlocked then
            table.insert(saveData.unlockedAchievements, achievement.key)
        end
    end
    
    -- Placeholder for file saving
    print("💾 Achievements would be saved here")
    -- love.filesystem.write("achievements.json", json.encode(saveData))
end

function Achievements:load()
    -- Placeholder for loading achievements
    print("📁 Achievements would be loaded here")
    -- In real implementation, load from Steam or local file
end

function Achievements:draw(x, y, w, h)
    love.graphics.setColor(0.95,0.95,0.95,0.8)
    love.graphics.rectangle('fill', x, y, w, h, 10, 10)
    love.graphics.setColor(0.1,0.1,0.1)
    
    -- Title
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf('🏆 ACHIEVEMENTS', x, y+8, w, 'center')
    
    -- Personal stats
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.printf('Personal Stats:', x+10, y+32, w-20, 'left')
    love.graphics.printf('Levels Won: '..self.personal.wins, x+20, y+52, w-40, 'left')
    love.graphics.printf('Zones Closed: '..self.personal.zones, x+20, y+72, w-40, 'left')
    love.graphics.printf('Shapes Drawn: '..self.personal.shapesDrawn, x+20, y+92, w-40, 'left')
    love.graphics.printf('Best Territory: '..self.personal.best..'%', x+20, y+112, w-40, 'left')
    love.graphics.printf('Play Time: '..math.floor(self.personal.playTime/60)..'m', x+20, y+132, w-40, 'left')
    
    -- Achievement progress
    local unlockedCount = 0
    for _, a in ipairs(self.list) do
        if a.unlocked then unlockedCount = unlockedCount + 1 end
    end
    
    love.graphics.printf('Progress: '..unlockedCount..'/'..#self.list..' unlocked', x+10, y+162, w-20, 'left')
    
    -- Achievement list (scrollable in real implementation)
    local ay = y+185
    local maxVisible = math.floor((h - 185) / 20)
    for i = 1, math.min(maxVisible, #self.list) do
        local a = self.list[i]
        love.graphics.setColor(a.unlocked and {0.2,0.8,0.2,1} or {0.5,0.5,0.5,0.7})
        local icon = a.unlocked and '🏆' or '🔒'
        love.graphics.printf(icon..' '..a.label, x+20, ay, w-40, 'left')
        ay = ay + 20
    end
    
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.setColor(1,1,1)
end

return Achievements
