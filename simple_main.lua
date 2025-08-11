-- Simple Voidline - Minimal working version
-- This is a simplified version that demonstrates the core Qix-style gameplay

local love = require "love"

-- Game state
local gameState = {
    MENU = "menu",
    PLAYING = "playing",
    GAME_OVER = "game_over"
}
local currentState = gameState.MENU

-- Grid settings
local GRID_WIDTH = 40
local GRID_HEIGHT = 25
local CELL_SIZE = 16
local grid = {}

-- Player
local player = {
    x = 2,
    y = 2,
    trail = {},
    isDrawing = false,
    speed = 0.1,
    moveTimer = 0
}

-- Enemy
local enemy = {
    x = GRID_WIDTH / 2,
    y = GRID_HEIGHT / 2,
    speed = 0.05,
    moveTimer = 0
}

-- Game stats
local claimedCells = 0
local totalCells = (GRID_WIDTH - 2) * (GRID_HEIGHT - 2) -- Excluding borders

function love.load()
    love.window.setTitle("Voidline - Simple Version")
    love.window.setMode(GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE + 100)
    
    -- Initialize grid
    for x = 1, GRID_WIDTH do
        grid[x] = {}
        for y = 1, GRID_HEIGHT do
            if x == 1 or x == GRID_WIDTH or y == 1 or y == GRID_HEIGHT then
                grid[x][y] = "wall"
            else
                grid[x][y] = "empty"
            end
        end
    end
    
    -- Set player starting position on border
    grid[player.x][player.y] = "safe"
end

function love.update(dt)
    if currentState == gameState.PLAYING then
        updateGame(dt)
    end
end

function updateGame(dt)
    -- Update player movement timer
    player.moveTimer = player.moveTimer + dt
    
    -- Handle player input
    if player.moveTimer >= player.speed then
        player.moveTimer = 0
        local newX, newY = player.x, player.y
        
        if love.keyboard.isDown("up") then
            newY = newY - 1
        elseif love.keyboard.isDown("down") then
            newY = newY + 1
        elseif love.keyboard.isDown("left") then
            newX = newX - 1
        elseif love.keyboard.isDown("right") then
            newX = newX + 1
        end
        
        -- Check if movement is valid
        if isValidMove(newX, newY) then
            movePlayer(newX, newY)
        end
    end
    
    -- Update enemy
    enemy.moveTimer = enemy.moveTimer + dt
    if enemy.moveTimer >= enemy.speed then
        enemy.moveTimer = 0
        moveEnemyTowardsPlayer()
    end
    
    -- Check collisions
    if math.abs(player.x - enemy.x) < 1 and math.abs(player.y - enemy.y) < 1 then
        if player.isDrawing then
            -- Player dies if hit while drawing
            currentState = gameState.GAME_OVER
        end
    end
    
    -- Check if enemy hits trail
    for _, trailPoint in ipairs(player.trail) do
        if math.abs(trailPoint.x - enemy.x) < 1 and math.abs(trailPoint.y - enemy.y) < 1 then
            currentState = gameState.GAME_OVER
        end
    end
end

function isValidMove(x, y)
    if x < 1 or x > GRID_WIDTH or y < 1 or y > GRID_HEIGHT then
        return false
    end
    return grid[x][y] ~= "wall"
end

function movePlayer(newX, newY)
    local oldCell = grid[player.x][player.y]
    
    -- If moving to empty area, start drawing
    if grid[newX][newY] == "empty" then
        if not player.isDrawing then
            player.isDrawing = true
            player.trail = {}
        end
        table.insert(player.trail, {x = player.x, y = player.y})
        grid[player.x][player.y] = "trail"
    end
    
    -- If returning to safe area while drawing, claim the area
    if player.isDrawing and (grid[newX][newY] == "safe" or grid[newX][newY] == "wall") then
        claimArea()
        player.isDrawing = false
        player.trail = {}
    end
    
    player.x = newX
    player.y = newY
    
    -- Mark new position as safe if on border or claimed area
    if grid[newX][newY] ~= "empty" and grid[newX][newY] ~= "trail" then
        grid[newX][newY] = "safe"
    end
end

function claimArea()
    -- Convert trail to claimed area (simplified flood fill)
    for _, point in ipairs(player.trail) do
        grid[point.x][point.y] = "claimed"
        claimedCells = claimedCells + 1
    end
    
    -- Simple area claiming - mark adjacent empty cells as claimed
    for _, point in ipairs(player.trail) do
        for dx = -1, 1 do
            for dy = -1, 1 do
                local x, y = point.x + dx, point.y + dy
                if x > 1 and x < GRID_WIDTH and y > 1 and y < GRID_HEIGHT then
                    if grid[x][y] == "empty" then
                        grid[x][y] = "claimed"
                        claimedCells = claimedCells + 1
                    end
                end
            end
        end
    end
end

function moveEnemyTowardsPlayer()
    local dx = player.x - enemy.x
    local dy = player.y - enemy.y
    
    if math.abs(dx) > math.abs(dy) then
        if dx > 0 then
            enemy.x = enemy.x + 0.5
        else
            enemy.x = enemy.x - 0.5
        end
    else
        if dy > 0 then
            enemy.y = enemy.y + 0.5
        else
            enemy.y = enemy.y - 0.5
        end
    end
end

function love.draw()
    if currentState == gameState.MENU then
        drawMenu()
    elseif currentState == gameState.PLAYING then
        drawGame()
    elseif currentState == gameState.GAME_OVER then
        drawGameOver()
    end
end

function drawMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("VOIDLINE", 0, 200, love.graphics.getWidth(), "center")
    love.graphics.printf("Press SPACE to start", 0, 250, love.graphics.getWidth(), "center")
    love.graphics.printf("Use arrow keys to move", 0, 300, love.graphics.getWidth(), "center")
    love.graphics.printf("Claim area by drawing loops", 0, 350, love.graphics.getWidth(), "center")
end

function drawGame()
    -- Draw grid
    for x = 1, GRID_WIDTH do
        for y = 1, GRID_HEIGHT do
            local screenX = (x - 1) * CELL_SIZE
            local screenY = (y - 1) * CELL_SIZE
            
            if grid[x][y] == "wall" then
                love.graphics.setColor(0.8, 0.8, 0.8)
            elseif grid[x][y] == "claimed" then
                love.graphics.setColor(0.2, 0.8, 0.3)
            elseif grid[x][y] == "trail" then
                love.graphics.setColor(1, 1, 0)
            elseif grid[x][y] == "safe" then
                love.graphics.setColor(0.4, 0.4, 0.8)
            else
                love.graphics.setColor(0.1, 0.1, 0.1)
            end
            
            love.graphics.rectangle("fill", screenX, screenY, CELL_SIZE - 1, CELL_SIZE - 1)
        end
    end
    
    -- Draw player
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", 
        (player.x - 1) * CELL_SIZE + 2, 
        (player.y - 1) * CELL_SIZE + 2, 
        CELL_SIZE - 4, CELL_SIZE - 4)
    
    -- Draw enemy
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.circle("fill", 
        (enemy.x - 0.5) * CELL_SIZE, 
        (enemy.y - 0.5) * CELL_SIZE, 
        CELL_SIZE / 3)
    
    -- Draw UI
    love.graphics.setColor(1, 1, 1)
    local percentage = (claimedCells / totalCells) * 100
    love.graphics.print(string.format("Claimed: %.1f%%", percentage), 10, GRID_HEIGHT * CELL_SIZE + 10)
    love.graphics.print("Status: " .. (player.isDrawing and "Drawing" or "Safe"), 10, GRID_HEIGHT * CELL_SIZE + 30)
    love.graphics.print("ESC: Menu", 10, GRID_HEIGHT * CELL_SIZE + 50)
end

function drawGameOver()
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.printf("GAME OVER", 0, 200, love.graphics.getWidth(), "center")
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press R to restart", 0, 250, love.graphics.getWidth(), "center")
    love.graphics.printf("Press ESC for menu", 0, 300, love.graphics.getWidth(), "center")
end

function love.keypressed(key)
    if key == "escape" then
        if currentState == gameState.PLAYING then
            currentState = gameState.MENU
        elseif currentState == gameState.GAME_OVER then
            currentState = gameState.MENU
        end
    elseif key == "space" and currentState == gameState.MENU then
        restartGame()
        currentState = gameState.PLAYING
    elseif key == "r" and currentState == gameState.GAME_OVER then
        restartGame()
        currentState = gameState.PLAYING
    end
end

function restartGame()
    -- Reset player
    player.x = 2
    player.y = 2
    player.trail = {}
    player.isDrawing = false
    
    -- Reset enemy
    enemy.x = GRID_WIDTH / 2
    enemy.y = GRID_HEIGHT / 2
    
    -- Reset grid
    claimedCells = 0
    for x = 1, GRID_WIDTH do
        for y = 1, GRID_HEIGHT do
            if x == 1 or x == GRID_WIDTH or y == 1 or y == GRID_HEIGHT then
                grid[x][y] = "wall"
            else
                grid[x][y] = "empty"
            end
        end
    end
    grid[player.x][player.y] = "safe"
end
