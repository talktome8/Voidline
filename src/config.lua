-- src/config.lua
-- Centralized configuration system for better scalability and maintainability

local Config = {}

-- === DISPLAY SETTINGS ===
Config.display = {
    defaultWidth = 1024,
    defaultHeight = 768,
    minWidth = 800,
    minHeight = 600,
    title = "Voidline - Territory Capture",
    vsync = true,
    resizable = true,
    
    -- Grid cell colors
    colors = {
        empty = {0.1, 0.1, 0.15, 1.0},          -- Dark blue for empty cells
        claimed = {0.2, 0.6, 1.0, 0.8},         -- Bright blue for claimed territory
        trail = {0.3, 0.8, 1.0, 0.9},           -- Light blue for player trail
        player = {1.0, 1.0, 1.0, 1.0},          -- White for player
        enemy = {0.9, 0.2, 0.2, 1.0},           -- Red for enemies
        border = {0.4, 0.4, 0.6, 1.0},          -- Gray for borders
        highlight = {1.0, 1.0, 0.3, 0.8},       -- Yellow for highlights
        island = {0.6, 0.3, 0.9, 0.7}           -- Purple for islands
    }
}

-- === GRID SETTINGS ===
Config.grid = {
    -- Increased cell size for better visibility (was 6px, now much larger)
    cellSize = 12,
    -- Optimized grid dimensions for better gameplay balance
    width = 60,
    height = 45,
    -- Border thickness
    borderWidth = 1,
    -- Animation settings
    animationSpeed = 0.5
}

-- === PLAYER SETTINGS ===
Config.player = {
    -- Movement speed (cells per second)
    moveSpeed = 8,
    -- Trail thickness
    trailWidth = 2,
    -- Invulnerability time after respawn (seconds)
    invulnerabilityTime = 2.0,
    -- Starting lives
    startingLives = 3
}

-- === ENEMY SETTINGS ===
Config.enemy = {
    -- Base settings
    baseMoveSpeed = 3,
    detectionRange = 8,
    -- Progressive difficulty multipliers
    speedMultiplierPerLevel = 0.15,
    countMultiplierPerLevel = 0.2,
    -- Smart AI settings
    pathfindingEnabled = true,
    adaptiveAI = true,
    -- Behavioral parameters
    aggressionLevel = 0.7,
    patrolRadius = 6
}

-- === LEVEL PROGRESSION ===
Config.levels = {
    -- Territory percentage required to complete level
    territoryThresholds = {15, 25, 35, 45, 55, 65, 75, 80, 85, 90},
    -- Enemy spawn patterns (enemy count per level)
    enemyProgression = {
        {count = 1, types = {"chaser"}},
        {count = 2, types = {"chaser", "patroller"}},
        {count = 2, types = {"chaser", "smart"}},
        {count = 3, types = {"chaser", "smart", "patroller"}},
        {count = 3, types = {"chaser", "smart", "interceptor"}},
        {count = 4, types = {"chaser", "smart", "interceptor", "patroller"}},
        {count = 4, types = {"chaser", "smart", "interceptor", "adaptive"}},
        {count = 5, types = {"chaser", "smart", "interceptor", "adaptive", "swarm"}},
        {count = 5, types = {"smart", "interceptor", "adaptive", "swarm", "boss"}},
        {count = 6, types = {"smart", "interceptor", "adaptive", "swarm", "boss", "phantom"}}
    },
    maxLevel = 10
}

-- === UI SETTINGS ===
Config.ui = {
    -- Menu system
    menuFadeTime = 0.3,
    maxMenuOptions = 6,
    buttonHeight = 40,
    buttonSpacing = 10,
    
    -- HUD
    hudPadding = 10,
    hudFontSize = 16,
    progressBarHeight = 20,
    
    -- Responsive breakpoints
    mobileBreakpoint = 800,
    tabletBreakpoint = 1024,
    
    -- Colors
    colors = {
        primary = {0.2, 0.6, 1.0, 1.0},
        secondary = {0.8, 0.4, 0.2, 1.0},
        success = {0.2, 0.8, 0.3, 1.0},
        warning = {1.0, 0.7, 0.2, 1.0},
        danger = {0.9, 0.2, 0.2, 1.0},
        background = {0.05, 0.05, 0.1, 0.9},
        overlay = {0.0, 0.0, 0.0, 0.5}
    }
}

-- === GAMEPLAY SETTINGS ===
Config.gameplay = {
    -- Scoring
    baseScore = 100,
    areaMultiplier = 10,
    speedBonus = 5,
    perfectBonus = 1000,
    
    -- Power-ups
    powerupSpawnChance = 0.1,
    powerupDuration = 10.0,
    
    -- Physics
    collisionTolerance = 0.3,
    trailCollisionEnabled = true
}

-- === AUDIO SETTINGS ===
Config.audio = {
    masterVolume = 0.8,
    musicVolume = 0.6,
    sfxVolume = 0.9,
    enableSpatialAudio = true
}

-- === DEBUG SETTINGS ===
Config.debug = {
    enabled = false,
    showFPS = true,
    showGrid = false,
    showCollisionBoxes = false,
    logLevel = "INFO" -- "DEBUG", "INFO", "WARN", "ERROR"
}

-- === UTILITY FUNCTIONS ===

-- Get scaled value based on display size
function Config:getScaledValue(baseValue, scaleFactor)
    scaleFactor = scaleFactor or 1.0
    local screenScale = math.min(
        love.graphics.getWidth() / self.display.defaultWidth,
        love.graphics.getHeight() / self.display.defaultHeight
    )
    return baseValue * screenScale * scaleFactor
end

-- Get responsive font size
function Config:getFontSize(baseSize)
    return math.floor(self:getScaledValue(baseSize))
end

-- Get enemy count for current level
function Config:getEnemyCount(level)
    level = math.min(level, #self.levels.enemyProgression)
    local progression = self.levels.enemyProgression[level]
    return progression.count
end

-- Get enemy types for current level
function Config:getEnemyTypes(level)
    level = math.min(level, #self.levels.enemyProgression)
    local progression = self.levels.enemyProgression[level]
    return progression.types
end

-- Get territory threshold for level
function Config:getTerritoryThreshold(level)
    level = math.min(level, #self.levels.territoryThresholds)
    return self.levels.territoryThresholds[level]
end

-- Validate configuration on load
function Config:validate()
    assert(self.grid.cellSize > 0, "Grid cell size must be positive")
    assert(self.grid.width > 0 and self.grid.height > 0, "Grid dimensions must be positive")
    assert(self.player.moveSpeed > 0, "Player move speed must be positive")
    assert(#self.levels.territoryThresholds > 0, "Must have at least one level")
    return true
end

-- Initialize configuration
Config:validate()

return Config
