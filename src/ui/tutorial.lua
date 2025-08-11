-- Tutorial System for Voidline
local Tutorial = {}

Tutorial.active = false
Tutorial.currentStep = 1
Tutorial.steps = {
    {
        title = "Welcome to Voidline!",
        text = "Use WASD or arrow keys to move your character around the grid.",
        condition = "move", -- Wait for player to move
        duration = 8.0
    },
    {
        title = "Territory Capture",
        text = "When you move outside safe areas, you'll start drawing a trail. Return to a safe area to capture territory!",
        condition = "capture", -- Wait for first area capture
        duration = 15.0
    },
    {
        title = "Shape Drawing Challenge",
        text = "See the target shape in the top-right? Match it by drawing with 80% accuracy for bonus points!",
        condition = "shape", -- Wait for decent shape attempt
        duration = 12.0
    },
    {
        title = "Avoid Enemies",
        text = "Red enemies will destroy your trail if they touch you! Plan your moves carefully.",
        condition = "enemy_avoid", -- Wait for player to be near enemy
        duration = 10.0
    },
    {
        title = "Use Abilities",
        text = "Press P for Panic Pulse (push enemies away) or M for Zone Mirror (duplicate captured areas).",
        condition = "ability", -- Wait for ability use
        duration = 12.0
    },
    {
        title = "Victory Conditions",
        text = "Capture 75% territory OR complete the shape challenge to advance to the next level!",
        condition = "complete", -- Tutorial complete
        duration = 8.0
    }
}

Tutorial.currentTimer = 0.0
Tutorial.playerMoved = false
Tutorial.playerCaptured = false
Tutorial.playerShapeAttempt = false
Tutorial.playerNearEnemy = false
Tutorial.playerUsedAbility = false

function Tutorial:start()
    if love.filesystem.getInfo("tutorial_completed.txt") then
        -- Tutorial already completed, skip
        return false
    end
    
    self.active = true
    self.currentStep = 1
    self.currentTimer = 0.0
    do local ok, Config = pcall(require, 'src.config'); if ok and Config.debug and Config.debug.enabled then print("Tutorial started!") end end
    return true
end

function Tutorial:update(dt, player, enemies, gameData)
    if not self.active then return end
    
    self.currentTimer = self.currentTimer + dt
    local step = self.steps[self.currentStep]
    if not step then
        self:complete()
        return
    end
    
    -- Check step conditions
    local conditionMet = false
    
    if step.condition == "move" then
        if player and (player.i ~= 1 or player.j ~= math.floor(20/2)) then
            self.playerMoved = true
            conditionMet = true
        end
    elseif step.condition == "capture" then
        if gameData and gameData.territoryPercent and gameData.territoryPercent > 5 then
            self.playerCaptured = true
            conditionMet = true
        end
    elseif step.condition == "shape" then
        if gameData and gameData.shapeAccuracy and gameData.shapeAccuracy > 30 then
            self.playerShapeAttempt = true
            conditionMet = true
        end
    elseif step.condition == "enemy_avoid" then
        if player and enemies then
            for _, enemy in ipairs(enemies) do
                local distance = math.abs(player.i - enemy.i) + math.abs(player.j - enemy.j)
                if distance <= 3 then
                    self.playerNearEnemy = true
                    conditionMet = true
                    break
                end
            end
        end
        -- Auto-advance after timer
        if self.currentTimer >= step.duration then
            conditionMet = true
        end
    elseif step.condition == "ability" then
        -- This will be set externally when abilities are used
        conditionMet = self.playerUsedAbility or self.currentTimer >= step.duration
    elseif step.condition == "complete" then
        conditionMet = self.currentTimer >= step.duration
    end
    
    -- Advance to next step
    if conditionMet or self.currentTimer >= step.duration then
        self:nextStep()
    end
end

function Tutorial:nextStep()
    self.currentStep = self.currentStep + 1
    self.currentTimer = 0.0
    
    if self.currentStep > #self.steps then
        self:complete()
    else
    do local ok, Config = pcall(require, 'src.config'); if ok and Config.debug and Config.debug.enabled then print("Tutorial step", self.currentStep, ":", self.steps[self.currentStep].title) end end
    end
end

function Tutorial:complete()
    self.active = false
    do local ok, Config = pcall(require, 'src.config'); if ok and Config.debug and Config.debug.enabled then print("Tutorial completed! You're ready to play Voidline!") end end
    
    -- Save completion status
    love.filesystem.write("tutorial_completed.txt", "completed")
    
    -- Unlock tutorial achievement
    local Achievements = require('src.ui.achievements')
    Achievements:unlock("firstSteps", true)
end

function Tutorial:onAbilityUsed()
    self.playerUsedAbility = true
end

function Tutorial:skip()
    self:complete()
end

function Tutorial:draw()
    if not self.active then return end
    
    local step = self.steps[self.currentStep]
    if not step then return end
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Tutorial panel
    local panelWidth = 400
    local panelHeight = 120
    local panelX = (screenWidth - panelWidth) / 2
    local panelY = screenHeight - panelHeight - 50
    
    -- Background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.95)
    love.graphics.rectangle('fill', panelX, panelY, panelWidth, panelHeight, 10, 10)
    
    -- Border with tutorial color
    love.graphics.setColor(0.3, 0.8, 1.0, 1.0)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle('line', panelX, panelY, panelWidth, panelHeight, 10, 10)
    love.graphics.setLineWidth(1)
    
    -- Tutorial icon and title
    love.graphics.setColor(0.3, 0.8, 1.0, 1.0)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("🎓 " .. step.title, panelX + 10, panelY + 10, panelWidth - 20, 'center')
    
    -- Tutorial text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.printf(step.text, panelX + 15, panelY + 35, panelWidth - 30, 'left')
    
    -- Progress indicator
    love.graphics.setColor(0.3, 0.8, 1.0, 1.0)
    local progressText = "Step " .. self.currentStep .. " of " .. #self.steps .. " • Press ESC to skip"
    love.graphics.printf(progressText, panelX + 10, panelY + panelHeight - 25, panelWidth - 20, 'center')
    
    -- Progress bar
    local progressWidth = panelWidth - 40
    local progress = self.currentStep / #self.steps
    
    love.graphics.setColor(0.2, 0.2, 0.3, 0.8)
    love.graphics.rectangle('fill', panelX + 20, panelY + panelHeight - 12, progressWidth, 8, 4, 4)
    love.graphics.setColor(0.3, 0.8, 1.0, 1.0)
    love.graphics.rectangle('fill', panelX + 20, panelY + panelHeight - 12, progressWidth * progress, 8, 4, 4)
    
    -- Reset graphics state
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(16))
end

function Tutorial:keypressed(key)
    if not self.active then return false end
    
    if key == 'escape' then
        self:skip()
        return true
    end
    
    return false
end

return Tutorial
