--[[
Voidline Stage System
--------------------
This file defines the modular stage system for Voidline. Each stage can define its own rules, enemies, powerups, and special logic.
Each stage is a table with the following fields:
- name: Stage name (string)
- description: Short description (string)
- gridW, gridH: Grid size (int)
- requiredPercent: Percent of grid to claim to win (float)
- enemies: function(level, enemiesLib, Grid) -> table of enemies
- powerups: function(level, PowerUps, Grid) -> table of powerups
- special: function(Game, Player, Grid) -- optional per-stage logic
See each stage definition for details.
]]

local stages = {}

-- Example: Stage 1 (Classic)
stages[1] = {
    name = "Classic Start",
    description = "Standard grid, basic enemies. Learn the ropes!",
    gridW = 24,
    gridH = 16,
    requiredPercent = 0.3,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Chaser:new(Grid.width-1, 2, level),
            enemiesLib.Chaser:new(2, Grid.height-1, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {} -- No powerups in stage 1
    end,
    special = function(Game, Player, Grid) end
}

-- Example: Stage 2 (Jammers)
stages[2] = {
    name = "Jammer Invasion",
    description = "Jammers appear! Avoid their zones.",
    gridW = 24,
    gridH = 16,
    requiredPercent = 0.4,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Chaser:new(Grid.width-1, Grid.height-1, level),
            enemiesLib.Jammer:new(2, 2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(3, 3, 6, 1.5)}
    end,
    special = function(Game, Player, Grid) end
}

-- Stage 3: Hazard Grid
stages[3] = {
    name = "Hazard Grid",
    description = "Some cells are blocked! Plan your path.",
    gridW = 28,
    gridH = 14,
    requiredPercent = 0.5,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Chaser:new(Grid.width-2, 2, level),
            enemiesLib.Jammer:new(2, Grid.height-2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(Grid.width-3, 3, 6, 1.7)}
    end,
    special = function(Game, Player, Grid)
        -- Block some cells
        for i=6,10 do
            for j=6,8 do
                if Grid.cells[i] then Grid.cells[i][j] = 'obstacle' end
            end
        end
    end
}

-- Stage 4: Infester Outbreak
stages[4] = {
    name = "Infester Outbreak",
    description = "Infester enemies infect claimed zones. Close them in to remove the infection!",
    gridW = 24,
    gridH = 16,
    requiredPercent = 0.6,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Chaser:new(Grid.width-2, 2, level),
            enemiesLib.Infester:new(2, 2, level),
            enemiesLib.Infester:new(Grid.width-3, Grid.height-3, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(4, 4, 6, 1.5)}
    end,
    special = function(Game, Player, Grid) end
}

-- Stage 5: Boss & Powerup Frenzy
stages[5] = {
    name = "Boss: The Reclaimer",
    description = "Face the Reclaimer! Many powerups appear.",
    gridW = 20,
    gridH = 20,
    requiredPercent = 0.6,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Reclaimer:new(Grid.width-2, 2, level),
            enemiesLib.Jammer:new(2, Grid.height-2, level),
            enemiesLib.Jammer:new(Grid.width-3, 3, level),
            enemiesLib.ReclaimerBoss:new(math.floor(Grid.width/2), math.floor(Grid.height/2))
        }
    end,
    powerups = function(level, PowerUps, Grid)
        local p = {}
        for i=1,4 do
            table.insert(p, PowerUps.SpeedBoost:new(2+i*3, 2+i*2, 5, 1.5+i*0.1))
        end
        return p
    end,
    special = function(Game, Player, Grid)
        -- Remove darkness if set
        Grid.isDark = false
    end
}

-- Stage 6: Flooded Grid
stages[6] = {
    name = "Flooded Grid",
    description = "Water cells block your path. Plan carefully!",
    gridW = 28,
    gridH = 14,
    requiredPercent = 0.65,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Chaser:new(Grid.width-2, 2, level),
            enemiesLib.Jammer:new(2, Grid.height-2, level),
            enemiesLib.GuardianBreaker:new(Grid.width-2, Grid.height-2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(Grid.width-3, 3, 6, 1.7)}
    end,
    special = function(Game, Player, Grid)
        -- Block a river in the middle
        for i=math.floor(Grid.width/2)-1,math.floor(Grid.width/2)+1 do
            for j=2,Grid.height-1 do
                if Grid.cells[i] then Grid.cells[i][j] = 'obstacle' end
            end
        end
    end
}

-- Stage 7: Teleporter Mayhem
stages[7] = {
    name = "Teleporter Mayhem",
    description = "Teleporters jump around the grid unpredictably!",
    gridW = 24,
    gridH = 16,
    requiredPercent = 0.7,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Teleporter:new(2, 2),
            enemiesLib.Teleporter:new(Grid.width-2, Grid.height-2),
            enemiesLib.Chaser:new(Grid.width-2, 2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.Freeze}
    end,
    special = function(Game, Player, Grid) end
}

-- Stage 8: Moving Obstacles
stages[8] = {
    name = "Moving Walls",
    description = "Obstacles move every 10 seconds!",
    gridW = 26,
    gridH = 16,
    requiredPercent = 0.7,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Chaser:new(Grid.width-1, 2, level),
            enemiesLib.Jammer:new(2, Grid.height-1, level),
            enemiesLib.GuardianBreaker:new(Grid.width-2, Grid.height-2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(3, 3, 6, 1.5)}
    end,
    special = function(Game, Player, Grid)
        -- Example: move obstacles every 10 seconds
        if not Grid._moveObstacles then
            Grid._moveObstacles = function(dt, Grid)
                -- Implement obstacle movement logic here
            end
        end
    end
}

-- Stage 9: Pulse Mines
stages[9] = {
    name = "Pulse Mines",
    description = "Timed shockwaves cross the grid. Avoid the pulses!",
    gridW = 30,
    gridH = 18,
    requiredPercent = 0.65,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Chaser:new(Grid.width-2, 2, level),
            enemiesLib.Jammer:new(2, Grid.height-2, level),
            enemiesLib.GuardianBreaker:new(Grid.width-2, Grid.height-2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(Grid.width-3, 3, 6, 1.7)}
    end,
    special = function(Game, Player, Grid)
        -- Pulse logic handled in realms/pulse_mines.lua
        if not Grid._pulseTimer then Grid._pulseTimer = 0 end
    end
}

-- Stage 10: Dark Arena
stages[10] = {
    name = "Dark Arena",
    description = "Limited visibility. Only see near your trail!",
    gridW = 28,
    gridH = 16,
    requiredPercent = 0.7,
    enemies = function(level, enemiesLib, Grid)
        local infester = nil
        if enemiesLib.Infester then
            infester = enemiesLib.Infester:new(math.floor(Grid.width/2), math.floor(Grid.height/2), level)
        end
        local result = {
            enemiesLib.Chaser:new(Grid.width-2, 2, level),
            enemiesLib.Jammer:new(2, Grid.height-2, level)
        }
        if infester then table.insert(result, infester) end
        return result
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(Grid.width-3, 3, 6, 1.7)}
    end,
    special = function(Game, Player, Grid)
        -- Darkness handled in realm logic
    end
}

-- Stage 11: Spiral Zone
stages[11] = {
    name = "Spiral Zone",
    description = "Grid rotates every 20 seconds!",
    gridW = 26,
    gridH = 16,
    requiredPercent = 0.7,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Chaser:new(Grid.width-1, 2, level),
            enemiesLib.Jammer:new(2, Grid.height-1, level),
            enemiesLib.GuardianBreaker:new(Grid.width-2, Grid.height-2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(3, 3, 6, 1.5)}
    end,
    special = function(Game, Player, Grid)
        if not Grid._spiralTimer then Grid._spiralTimer = 0 end
        -- Implement spiral/rotation logic in realm if desired
    end
}

-- Stage 12: Glitch Realm
stages[12] = {
    name = "Glitch Realm",
    description = "Rules change every 15 seconds!",
    gridW = 24,
    gridH = 16,
    requiredPercent = 0.75,
    enemies = function(level, enemiesLib, Grid)
        local infester = nil
        if enemiesLib.Infester then
            infester = enemiesLib.Infester:new(math.floor(Grid.width/2), 2, level)
        end
        local result = {
            enemiesLib.Chaser:new(Grid.width-1, 2, level),
            enemiesLib.Jammer:new(2, Grid.height-1, level)
        }
        if infester then table.insert(result, infester) end
        return result
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(3, 3, 6, 1.5)}
    end,
    special = function(Game, Player, Grid)
        if not Grid._glitchTimer then Grid._glitchTimer = 0 end
        -- Implement glitch logic in realm if desired
    end
}

-- Stage 13: Splitter & Phaser Mayhem
stages[13] = {
    name = "Splitter & Phaser Mayhem",
    description = "New enemies! Splitters multiply, Phasers pass through walls.",
    gridW = 28,
    gridH = 18,
    requiredPercent = 0.75,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Splitter:new(2, 2, level),
            enemiesLib.Splitter:new(Grid.width-2, Grid.height-2, level),
            enemiesLib.Phaser:new(math.floor(Grid.width/2), math.floor(Grid.height/2), level),
            enemiesLib.Chaser:new(Grid.width-1, 2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(3, 3, 6, 1.7)}
    end,
    special = function(Game, Player, Grid) end
}

-- Stage 14: Ultimate Chaos
stages[14] = {
    name = "Ultimate Chaos",
    description = "All enemy types! Survive the onslaught.",
    gridW = 30,
    gridH = 20,
    requiredPercent = 0.8,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Chaser:new(Grid.width-1, 2, level),
            enemiesLib.Jammer:new(2, Grid.height-1, level),
            enemiesLib.GuardianBreaker:new(Grid.width-2, Grid.height-2, level),
            enemiesLib.Infester:new(2, 2, level),
            enemiesLib.Phaser:new(Grid.width-2, 2, level),
            enemiesLib.Splitter:new(2, Grid.height-2, level),
            enemiesLib.Reclaimer:new(Grid.width-3, 3, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(Grid.width-3, 3, 6, 1.8)}
    end,
    special = function(Game, Player, Grid) end
}

-- Stage 15: Boss Rush
stages[15] = {
    name = "Boss Rush",
    description = "Face multiple bosses in a tiny arena!",
    gridW = 10,
    gridH = 8,
    requiredPercent = 0.96,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.ReclaimerBoss:new(math.floor(Grid.width/2), math.floor(Grid.height/2)),
            enemiesLib.GuardianBreaker:new(2, 2)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(Grid.width-2, Grid.height-2, 5, 1.7)}
    end,
    special = function(Game, Player, Grid) end
}

-- Stage 16: The Voidline
stages[16] = {
    name = "The Voidline",
    description = "The final test. All hazards, all enemies, tiny grid. Survive!",
    gridW = 8,
    gridH = 6,
    requiredPercent = 0.98,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Chaser:new(2, 2, level),
            enemiesLib.Jammer:new(Grid.width-2, 2, level),
            enemiesLib.Infester:new(2, Grid.height-2, level),
            enemiesLib.GuardianBreaker:new(Grid.width-2, Grid.height-2),
            enemiesLib.ReclaimerBoss:new(math.floor(Grid.width/2), math.floor(Grid.height/2))
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(math.floor(Grid.width/2), math.floor(Grid.height/2), 5, 2.0)}
    end,
    special = function(Game, Player, Grid)
        -- All hazards active
    end
}

-- Stage 17: Twin Threats
stages[17] = {
    name = "Twin Threats",
    description = "Two Chasers coordinate to trap you. Outsmart them!",
    gridW = 12,
    gridH = 8,
    requiredPercent = 0.96,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Chaser:new(2, 2, level),
            enemiesLib.Chaser:new(Grid.width-2, Grid.height-2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(math.floor(Grid.width/2), 2, 5, 1.7)}
    end,
    special = function(Game, Player, Grid) end
}

-- Stage 18: Jammer's Web
stages[18] = {
    name = "Jammer's Web",
    description = "Multiple Jammers create overlapping slow zones.",
    gridW = 12,
    gridH = 8,
    requiredPercent = 0.97,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Jammer:new(2, 2, level),
            enemiesLib.Jammer:new(Grid.width-2, 2, level),
            enemiesLib.Jammer:new(math.floor(Grid.width/2), Grid.height-2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(2, Grid.height-2, 5, 1.5)}
    end,
    special = function(Game, Player, Grid) end
}

-- Stage 19: Infection Spread
stages[19] = {
    name = "Infection Spread",
    description = "Infesters multiply if not contained quickly!",
    gridW = 10,
    gridH = 8,
    requiredPercent = 0.97,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Infester:new(2, 2, level),
            enemiesLib.Infester:new(Grid.width-2, Grid.height-2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(math.floor(Grid.width/2), math.floor(Grid.height/2), 5, 1.7)}
    end,
    special = function(Game, Player, Grid)
        -- Could add infester multiplication logic here
    end
}

-- Stage 20: Guardian's Last Stand
stages[20] = {
    name = "Guardian's Last Stand",
    description = "GuardianBreaker and Chaser team up in a tiny grid.",
    gridW = 10,
    gridH = 7,
    requiredPercent = 0.98,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.GuardianBreaker:new(2, 2),
            enemiesLib.Chaser:new(Grid.width-2, Grid.height-2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(Grid.width-2, 2, 5, 1.7)}
    end,
    special = function(Game, Player, Grid) end
}

-- Stage 21: Pulse Gauntlet
stages[21] = {
    name = "Pulse Gauntlet",
    description = "Pulses and Jammers combine for a timing challenge.",
    gridW = 10,
    gridH = 7,
    requiredPercent = 0.98,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Jammer:new(2, 2, level),
            enemiesLib.Jammer:new(Grid.width-2, Grid.height-2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(math.floor(Grid.width/2), 2, 5, 1.7)}
    end,
    special = function(Game, Player, Grid)
        -- Could add pulse logic here
    end
}

-- Stage 22: The Maze
stages[22] = {
    name = "The Maze",
    description = "Obstacles form a maze. Find your path!",
    gridW = 10,
    gridH = 7,
    requiredPercent = 0.98,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Chaser:new(2, 2, level),
            enemiesLib.Jammer:new(Grid.width-2, Grid.height-2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(2, 2, 5, 1.7)}
    end,
    special = function(Game, Player, Grid)
        -- Add maze obstacles
        for i=3,8,2 do
            for j=3,5 do
                if Grid.cells[i] then Grid.cells[i][j] = 'obstacle' end
            end
        end
    end
}

-- Stage 23: The Swarm
stages[23] = {
    name = "The Swarm",
    description = "Many weak Chasers, but they can surround you!",
    gridW = 10,
    gridH = 7,
    requiredPercent = 0.98,
    enemies = function(level, enemiesLib, Grid)
        local e = {}
        for k=1,5 do
            table.insert(e, enemiesLib.Chaser:new(2+(k%4), 2+(k%3), 1))
        end
        return e
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(math.floor(Grid.width/2), math.floor(Grid.height/2), 5, 1.7)}
    end,
    special = function(Game, Player, Grid) end
}

-- Stage 24: Glitch Finale
stages[24] = {
    name = "Glitch Finale",
    description = "Rules, visuals, and enemies change every 8 seconds!",
    gridW = 8,
    gridH = 6,
    requiredPercent = 0.99,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.Infester:new(2, 2, level),
            enemiesLib.Jammer:new(Grid.width-2, 2, level),
            enemiesLib.Chaser:new(math.floor(Grid.width/2), Grid.height-2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(Grid.width-2, Grid.height-2, 5, 2.0)}
    end,
    special = function(Game, Player, Grid)
        -- Could add glitch logic here
    end
}

-- Stage 25: Boss Gauntlet
stages[25] = {
    name = "Boss Gauntlet",
    description = "Face all bosses in sequence. Only the best survive!",
    gridW = 8,
    gridH = 6,
    requiredPercent = 0.99,
    enemies = function(level, enemiesLib, Grid)
        return {
            enemiesLib.ReclaimerBoss:new(2, 2),
            enemiesLib.GuardianBreaker:new(Grid.width-2, 2),
            enemiesLib.Jammer:new(math.floor(Grid.width/2), Grid.height-2, level)
        }
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(math.floor(Grid.width/2), math.floor(Grid.height/2), 5, 2.0)}
    end,
    special = function(Game, Player, Grid) end
}

-- Stage 26: The Endless Void
stages[26] = {
    name = "The Endless Void",
    description = "Endless enemies, tiny grid. How long can you last?",
    gridW = 6,
    gridH = 5,
    requiredPercent = 1.0,
    enemies = function(level, enemiesLib, Grid)
        local e = {
            enemiesLib.Chaser:new(2, 2, level),
            enemiesLib.Jammer:new(Grid.width-2, 2, level),
            enemiesLib.Infester:new(2, Grid.height-2, level),
            enemiesLib.GuardianBreaker:new(Grid.width-2, Grid.height-2),
            enemiesLib.ReclaimerBoss:new(math.floor(Grid.width/2), math.floor(Grid.height/2))
        }
        -- Add a new Chaser every 10 seconds (handled in special)
        return e
    end,
    powerups = function(level, PowerUps, Grid)
        return {PowerUps.SpeedBoost:new(math.floor(Grid.width/2), math.floor(Grid.height/2), 5, 2.2)}
    end,
    special = function(Game, Player, Grid)
        if not Grid._endlessTimer then Grid._endlessTimer = 0 end
        Grid._endlessAddEnemy = function(dt, enemiesLib, Grid, enemies)
            Grid._endlessTimer = Grid._endlessTimer + dt
            if Grid._endlessTimer > 10 then
                table.insert(enemies, enemiesLib.Chaser:new(2, 2, 1))
                Grid._endlessTimer = 0
            end
        end
    end
}

-- Auto-generate stages 31-100 for scalable progression
for i = 31, 100 do
    local bossStage = (i % 10 == 0)
    local realmNames = {
        [1] = "Void Hatchery",
        [2] = "Pulse Mines",
        [3] = "Echo Lab",
        [4] = "Dark Arena",
        [5] = "Light Spiral",
        [6] = "Glitch Zone",
        [7] = "Infested Maze",
        [8] = "Jammer's Web",
        [9] = "Guardian's Gauntlet",
        [10] = "The Spiral"
    }
    local realmIdx = math.floor((i-1)/10) + 1
    local realmName = realmNames[realmIdx] or ("Unknown Realm "..realmIdx)
    local gridW = 24 - math.floor((i-1)/20)*2 -- Gradually shrink grid for difficulty
    local gridH = 16 - math.floor((i-1)/20)
    local requiredPercent = 0.7 + 0.003 * (i-1) -- Slightly increase required percent
    local stage = {
        name = bossStage and (realmName.." Boss ("..math.floor(i/10)..")") or (realmName.." - Stage "..(i%10)),
        description = bossStage and ("Boss of "..realmName.." with unique powers!") or ("Unique hazards and enemy patterns in "..realmName.."."),
        gridW = gridW,
        gridH = gridH,
        requiredPercent = math.min(requiredPercent, 0.98),
        enemies = function(level, enemiesLib, Grid)
            local e = {}
            -- Realm-specific enemy logic with more variety, unique behaviors, and special cases
            if realmIdx == 1 then -- Void Hatchery: Chasers, occasional Jammer, rare Infester
                table.insert(e, enemiesLib.Chaser:new(2, 2, i))
                if i % 4 == 0 then table.insert(e, enemiesLib.Jammer:new(Grid.width-2, 2, i)) end
                if i % 7 == 0 then table.insert(e, enemiesLib.Infester:new(math.floor(Grid.width/2), Grid.height-2, i)) end
            elseif realmIdx == 2 then -- Pulse Mines: Jammers, Chasers, rare Infester, Jammer disables powerups
                table.insert(e, enemiesLib.Jammer:new(2, 2, i))
                table.insert(e, enemiesLib.Chaser:new(Grid.width-2, 2, i))
                if i % 3 == 0 then table.insert(e, enemiesLib.Jammer:new(Grid.width-2, Grid.height-2, i)) end
                if i % 8 == 0 then table.insert(e, enemiesLib.Infester:new(math.floor(Grid.width/2), math.floor(Grid.height/2), i)) end
            elseif realmIdx == 3 then -- Echo Lab: Infesters multiply, Chasers, rare GuardianBreaker
                table.insert(e, enemiesLib.Infester:new(2, 2, i))
                table.insert(e, enemiesLib.Chaser:new(Grid.width-2, Grid.height-2, i))
                if i % 4 == 0 then table.insert(e, enemiesLib.Infester:new(Grid.width-2, 2, i)) end
                if i % 6 == 0 then table.insert(e, enemiesLib.GuardianBreaker:new(math.floor(Grid.width/2), 2, i)) end
            elseif realmIdx == 4 then -- Dark Arena: Chasers, GuardianBreaker, rare Jammer, enemies move faster in darkness
                table.insert(e, enemiesLib.Chaser:new(2, 2, i))
                if i > 45 then table.insert(e, enemiesLib.GuardianBreaker:new(Grid.width-2, 2, i)) end
                if i % 5 == 0 then table.insert(e, enemiesLib.Jammer:new(2, Grid.height-2, i)) end
            elseif realmIdx == 5 then -- Light Spiral: Chasers, Jammers, Infesters, rare Reclaimer, spiral spawn pattern
                table.insert(e, enemiesLib.Chaser:new(2, 2, i))
                table.insert(e, enemiesLib.Jammer:new(Grid.width-2, 2, i))
                if i % 3 == 0 then table.insert(e, enemiesLib.Infester:new(Grid.width-2, Grid.height-2, i)) end
                if i % 9 == 0 then table.insert(e, enemiesLib.Reclaimer:new(2, math.floor(Grid.height/2), i)) end
            elseif realmIdx == 6 then -- Glitch Zone: All types, random, rare double bosses, enemies swap types mid-stage
                local types = {enemiesLib.Chaser, enemiesLib.Jammer, enemiesLib.Infester, enemiesLib.GuardianBreaker}
                for n=1,2+((i%3)==0 and 1 or 0) do
                    local t = types[1+((i+n)%#types)]
                    table.insert(e, t:new(2+n, 2+n, i))
                end
                if i % 10 == 7 then table.insert(e, enemiesLib.ReclaimerBoss:new(math.floor(Grid.width/2), math.floor(Grid.height/2))) end
            elseif realmIdx == 7 then -- Infested Maze: Infesters multiply, Chasers, rare Jammer, maze obstacles
                table.insert(e, enemiesLib.Infester:new(2, 2, i))
                table.insert(e, enemiesLib.Infester:new(Grid.width-2, Grid.height-2, i))
                if i % 2 == 0 then table.insert(e, enemiesLib.Chaser:new(Grid.width-2, 2, i)) end
                if i % 5 == 0 then table.insert(e, enemiesLib.Jammer:new(2, math.floor(Grid.height/2), i)) end
            elseif realmIdx == 8 then -- Jammer's Web: Many Jammers, rare Infester, Jammers create overlapping slow zones
                table.insert(e, enemiesLib.Jammer:new(2, 2, i))
                table.insert(e, enemiesLib.Jammer:new(Grid.width-2, 2, i))
                if i % 2 == 1 then table.insert(e, enemiesLib.Jammer:new(Grid.width-2, Grid.height-2, i)) end
                if i % 6 == 0 then table.insert(e, enemiesLib.Infester:new(math.floor(Grid.width/2), 2, i)) end
            elseif realmIdx == 9 then -- Guardian's Gauntlet: GuardianBreaker, Chasers, rare Reclaimer, GuardianBreakers break claimed zones
                table.insert(e, enemiesLib.GuardianBreaker:new(2, 2, i))
                table.insert(e, enemiesLib.Chaser:new(Grid.width-2, Grid.height-2, i))
                if i % 3 == 0 then table.insert(e, enemiesLib.GuardianBreaker:new(Grid.width-2, 2, i)) end
                if i % 8 == 0 then table.insert(e, enemiesLib.Reclaimer:new(math.floor(Grid.width/2), 2, i)) end
            elseif realmIdx == 10 then -- The Spiral: All types, spiral pattern, rare double Infester, enemies rotate spawn points
                table.insert(e, enemiesLib.Chaser:new(2, 2, i))
                table.insert(e, enemiesLib.Jammer:new(Grid.width-2, 2, i))
                table.insert(e, enemiesLib.Infester:new(2, Grid.height-2, i))
                if i % 2 == 0 then table.insert(e, enemiesLib.GuardianBreaker:new(Grid.width-2, Grid.height-2, i)) end
                if i % 7 == 0 then table.insert(e, enemiesLib.Infester:new(math.floor(Grid.width/2), math.floor(Grid.height/2), i)) end
            end
            if bossStage then table.insert(e, enemiesLib.ReclaimerBoss:new(math.floor(Grid.width/2), math.floor(Grid.height/2))) end
            return e
        end,
        powerups = function(level, PowerUps, Grid)
            local p = {PowerUps.SpeedBoost:new(math.floor(Grid.width/2), math.floor(Grid.height/2), 5, 1.5 + 0.01*i)}
            -- Add more powerup types and strategic placements for variety
            if i % 7 == 0 then table.insert(p, PowerUps.SpeedBoost:new(2, 2, 4, 1.2 + 0.01*i)) end
            if i % 10 == 3 then table.insert(p, PowerUps.SpeedBoost:new(Grid.width-2, Grid.height-2, 6, 1.8)) end
            -- Example: rare double powerup
            if i % 15 == 0 then
                table.insert(p, PowerUps.SpeedBoost:new(math.floor(Grid.width/2), 2, 8, 2.0))
                table.insert(p, PowerUps.SpeedBoost:new(2, math.floor(Grid.height/2), 8, 2.0))
            end
            return p
        end,
        special = bossStage and function(Game, Player, Grid)
            -- Boss stage: all enemies move 20% faster and spawn a hazard wall
            for _, enemy in ipairs(Game.enemies) do
                enemy.moveDelay = enemy.moveDelay * 0.8
                -- Bosses flash red for 1s at start
                if enemy.isBoss then enemy._fuseHitColor = {1,0.2,0.2,1}; enemy._fuseHitTimer = 1 end
            end
            for j=2,Grid.height-1 do
                if Grid.cells[2] then Grid.cells[2][j] = 'obstacle' end
            end
            -- Add a brief screen shake
            if Game.shake then Game:shake(0.5, 6) end
            -- Show boss intro text (if UI supports)
            if Game.showBossIntro then Game:showBossIntro((realmName.." Boss ("..math.floor(i/10)..")")) end
            -- Add boss-specific music if supported
            if Game.setMusic then Game:setMusic('boss_theme') end
            -- Add boss health bar if supported
            if Game.showBossHealth then Game:showBossHealth(true) end
        end or function(Game, Player, Grid)
            -- Realm-specific hazards and polish
            if realmIdx == 2 and i % 3 == 0 then -- Pulse Mines: add pulse obstacles
                for k=2,Grid.width-1,4 do
                    if Grid.cells[k] then Grid.cells[k][math.floor(Grid.height/2)] = 'obstacle' end
                end
                -- Add pulse visual effect if available
                if Game.triggerPulseEffect then Game:triggerPulseEffect() end
            elseif realmIdx == 3 and i % 4 == 0 then -- Echo Lab: echo effect
                if not Grid._echoLabTimer then Grid._echoLabTimer = 2 end
                -- Add echo visual effect if available
                if Game.triggerEchoEffect then Game:triggerEchoEffect() end
            elseif realmIdx == 4 and i % 2 == 0 then -- Dark Arena: random obstacles
                for k=2,Grid.width-1,5 do
                    if Grid.cells[k] then Grid.cells[k][2] = 'obstacle' end
                end
                -- Add darkness overlay if available
                if Game.setDarkness then Game:setDarkness(true) end
            elseif realmIdx == 6 and i % 5 == 0 then -- Glitch Zone: randomize obstacles
                for k=2,Grid.width-1,3 do
                    if Grid.cells[k] then Grid.cells[k][Grid.height-2] = 'obstacle' end
                end
                -- Add glitch visual effect if available
                if Game.triggerGlitchEffect then Game:triggerGlitchEffect() end
            end
            -- Add subtle screen shake on every stage clear
            if Game.shake and Game.justClearedStage then Game:shake(0.2, 2) end
            -- Add realm-specific music/ambience if supported
            if Game.setMusic then
                local musicMap = {
                    [1] = 'void_hatchery', [2] = 'pulse_mines', [3] = 'echo_lab', [4] = 'dark_arena',
                    [5] = 'light_spiral', [6] = 'glitch_zone', [7] = 'infested_maze', [8] = 'jammer_web',
                    [9] = 'guardian_gauntlet', [10] = 'spiral_realm'
                }
                Game:setMusic(musicMap[realmIdx] or 'default')
            end
            -- Add realm intro popup if supported
            if Game.showStageIntro then
                Game:showStageIntro(realmName..' - שלב '..(i%10 == 0 and 10 or i%10), stages[i].description)
            end
        end
    }
    stages[i] = stage
end

return stages
