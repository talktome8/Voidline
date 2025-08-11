-- src/systems/shape_score.lua
-- Calculates scores and bonuses for shape drawing challenges

local ShapeScore = {}

function ShapeScore:init()
    self.baseScores = {
        territory = 100,    -- Points per % of territory captured
        shapeMatch = 1000,  -- Base points for shape completion
        timeBonus = 500,    -- Maximum time bonus
        enemyRisk = 200,    -- Bonus per enemy nearby while drawing
        precision = 300,    -- Bonus for high accuracy
        complexity = 150    -- Bonus per difficulty level
    }
    
    self.accuracyThresholds = {
        perfect = 0.95,     -- 95%+ accuracy
        excellent = 0.85,   -- 85%+ accuracy  
        good = 0.70,        -- 70%+ accuracy
        decent = 0.50,      -- 50%+ accuracy
        poor = 0.30         -- 30%+ accuracy (minimum for any points)
    }
    
    self.multipliers = {
        perfect = 2.0,
        excellent = 1.5,
        good = 1.2,
        decent = 1.0,
        poor = 0.5,
        failed = 0.0
    }
end

-- Calculate total score for a shape drawing attempt
function ShapeScore:calculateShapeScore(matchResult, drawData, gameContext)
    if not matchResult or not drawData then
        return {
            totalScore = 0,
            breakdown = {},
            grade = "failed",
            message = "Invalid drawing data"
        }
    end
    
    local accuracy = matchResult.finalAccuracy or matchResult.accuracy or 0
    local grade = self:getAccuracyGrade(accuracy)
    local multiplier = self.multipliers[grade] or 0
    
    if accuracy < self.accuracyThresholds.poor then
        return {
            totalScore = 0,
            breakdown = {accuracy = accuracy, grade = grade},
            grade = "failed",
            message = "Shape accuracy too low (" .. math.floor(accuracy * 100) .. "%)"
        }
    end
    
    local breakdown = {}
    local totalScore = 0
    
    -- Base shape completion score
    local baseScore = self.baseScores.shapeMatch * multiplier
    breakdown.baseShape = baseScore
    totalScore = totalScore + baseScore
    
    -- Precision bonus
    if accuracy >= self.accuracyThresholds.excellent then
        local precisionBonus = self.baseScores.precision * (accuracy - self.accuracyThresholds.excellent) / (1 - self.accuracyThresholds.excellent)
        breakdown.precision = precisionBonus
        totalScore = totalScore + precisionBonus
    end
    
    -- Time bonus
    if drawData.drawTime and gameContext and gameContext.template then
        local timeBonus = self:calculateTimeBonus(drawData.drawTime, gameContext.template.difficulty or 1)
        breakdown.time = timeBonus
        totalScore = totalScore + timeBonus
    end
    
    -- Enemy risk bonus
    if gameContext and gameContext.enemiesNearby then
        local riskBonus = gameContext.enemiesNearby * self.baseScores.enemyRisk
        breakdown.enemyRisk = riskBonus
        totalScore = totalScore + riskBonus
    end
    
    -- Complexity bonus
    if gameContext and gameContext.template and gameContext.template.difficulty then
        local complexityBonus = gameContext.template.difficulty * self.baseScores.complexity
        breakdown.complexity = complexityBonus
        totalScore = totalScore + complexityBonus
    end
    
    -- Apply final grade multiplier
    totalScore = math.floor(totalScore)
    
    return {
        totalScore = totalScore,
        breakdown = breakdown,
        grade = grade,
        accuracy = accuracy,
        message = self:getGradeMessage(grade, accuracy)
    }
end

-- Calculate territory capture score
function ShapeScore:calculateTerritoryScore(percentageCaptured, targetPercentage)
    local baseScore = percentageCaptured * self.baseScores.territory
    
    -- Bonus for exceeding target
    local bonus = 0
    if percentageCaptured > targetPercentage then
        local excess = percentageCaptured - targetPercentage
        bonus = excess * self.baseScores.territory * 0.5 -- 50% bonus for excess
    end
    
    return {
        baseScore = baseScore,
        bonus = bonus,
        totalScore = baseScore + bonus,
        percentage = percentageCaptured
    }
end

-- Calculate combined level score
function ShapeScore:calculateLevelScore(territoryResult, shapeResult, levelData)
    local total = 0
    local breakdown = {
        territory = territoryResult,
        shape = shapeResult
    }
    
    if territoryResult then
        total = total + territoryResult.totalScore
    end
    
    if shapeResult then
        total = total + shapeResult.totalScore
    end
    
    -- Level completion bonus
    local levelBonus = 0
    if levelData and levelData.level then
        levelBonus = levelData.level * 50 -- 50 points per level
        breakdown.levelBonus = levelBonus
        total = total + levelBonus
    end
    
    -- Perfect level bonus (both territory and shape excellent)
    if territoryResult and shapeResult and 
       territoryResult.percentage >= (levelData.targetPercentage or 75) and
       shapeResult.grade == "perfect" then
        local perfectBonus = 1000
        breakdown.perfectBonus = perfectBonus
        total = total + perfectBonus
    end
    
    return {
        totalScore = total,
        breakdown = breakdown
    }
end

-- Get accuracy grade based on percentage
function ShapeScore:getAccuracyGrade(accuracy)
    if accuracy >= self.accuracyThresholds.perfect then
        return "perfect"
    elseif accuracy >= self.accuracyThresholds.excellent then
        return "excellent"
    elseif accuracy >= self.accuracyThresholds.good then
        return "good"
    elseif accuracy >= self.accuracyThresholds.decent then
        return "decent"
    elseif accuracy >= self.accuracyThresholds.poor then
        return "poor"
    else
        return "failed"
    end
end

-- Get message for grade
function ShapeScore:getGradeMessage(grade, accuracy)
    local percent = math.floor(accuracy * 100)
    
    local messages = {
        perfect = "Perfect! (" .. percent .. "%)",
        excellent = "Excellent! (" .. percent .. "%)",
        good = "Good work! (" .. percent .. "%)",
        decent = "Not bad (" .. percent .. "%)",
        poor = "Needs improvement (" .. percent .. "%)",
        failed = "Try again (" .. percent .. "%)"
    }
    
    return messages[grade] or "Unknown result"
end

-- Calculate time bonus
function ShapeScore:calculateTimeBonus(drawTime, difficulty)
    local idealTime = 3 + difficulty * 2 -- 3-13 seconds ideal depending on difficulty
    local maxTime = idealTime * 3 -- Triple ideal time = no bonus
    
    if drawTime > maxTime then
        return 0 -- Too slow, no bonus
    end
    
    if drawTime < idealTime then
        -- Fast completion bonus
        local speedMultiplier = idealTime / drawTime
        return math.floor(self.baseScores.timeBonus * math.min(speedMultiplier, 2.0))
    else
        -- Partial bonus for reasonable time
        local timeRatio = (maxTime - drawTime) / (maxTime - idealTime)
        return math.floor(self.baseScores.timeBonus * timeRatio)
    end
end

-- Calculate enemies nearby bonus
function ShapeScore:calculateEnemyBonus(enemies, playerPosition, drawingArea)
    if not enemies or not playerPosition then return 0 end
    
    local nearbyCount = 0
    local dangerRadius = 50 -- Pixels
    
    for _, enemy in ipairs(enemies) do
        local distance = math.sqrt(
            (enemy.x - playerPosition.x)^2 + 
            (enemy.y - playerPosition.y)^2
        )
        
        if distance <= dangerRadius then
            nearbyCount = nearbyCount + 1
        end
    end
    
    return nearbyCount
end

-- Get score display information
function ShapeScore:getScoreDisplay(scoreResult)
    if not scoreResult then
        return {
            title = "No Score",
            color = {0.5, 0.5, 0.5, 1},
            icon = "?"
        }
    end
    
    local displays = {
        perfect = {
            title = "PERFECT!",
            color = {1, 0.8, 0, 1}, -- Gold
            icon = "★"
        },
        excellent = {
            title = "EXCELLENT!",
            color = {0.2, 1, 0.2, 1}, -- Green
            icon = "✓"
        },
        good = {
            title = "GOOD!",
            color = {0.2, 0.8, 1, 1}, -- Blue
            icon = "+"
        },
        decent = {
            title = "OK",
            color = {1, 1, 0.2, 1}, -- Yellow
            icon = "○"
        },
        poor = {
            title = "POOR",
            color = {1, 0.5, 0.2, 1}, -- Orange
            icon = "-"
        },
        failed = {
            title = "FAILED",
            color = {1, 0.2, 0.2, 1}, -- Red
            icon = "✗"
        }
    }
    
    return displays[scoreResult.grade] or displays.failed
end

-- Get high score information
function ShapeScore:isHighScore(score, previousBest)
    if not previousBest then return true end
    return score > previousBest
end

-- Format score for display
function ShapeScore:formatScore(score)
    if score >= 1000000 then
        return string.format("%.1fM", score / 1000000)
    elseif score >= 1000 then
        return string.format("%.1fK", score / 1000)
    else
        return tostring(score)
    end
end

-- Get achievement information
function ShapeScore:checkAchievements(scoreResult, gameStats)
    local achievements = {}
    
    if scoreResult.grade == "perfect" then
        table.insert(achievements, "Perfect Artist")
    end
    
    if scoreResult.breakdown and scoreResult.breakdown.enemyRisk and scoreResult.breakdown.enemyRisk > 0 then
        table.insert(achievements, "Risk Taker")
    end
    
    if scoreResult.breakdown and scoreResult.breakdown.time and scoreResult.breakdown.time > 400 then
        table.insert(achievements, "Speed Demon")
    end
    
    if gameStats and gameStats.consecutivePerfects and gameStats.consecutivePerfects >= 3 then
        table.insert(achievements, "Consistency Master")
    end
    
    return achievements
end

return ShapeScore
