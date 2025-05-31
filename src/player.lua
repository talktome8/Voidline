local Player = {}

function Player:load(grid, character)
    self.i = math.floor(grid.width/2)
    self.j = math.floor(grid.height/2)
    self.character = character or require('src.characters.architect')
    self.moveDelay = 0.15 / (self.character.speed or 2.0) -- Use character speed, default if not defined
    self.moveTimer = 0
    self.dir = {x=0, y=0}
    self.trail = {}
    self.isDrawing = false
    self.color = self.character.color or {0.2, 0.6, 1}
    self.trailColor = self.character.trailColor or {1, 0.8, 0.2}
    -- Initialize character-specific properties or timers here
    if self.character.name == "Trickster" then
        self.tricksterSwapTimer = 10 -- seconds
    end
end

local function isClaimed(grid, i, j)
    return grid.cells[i] and (grid.cells[i][j] == 'claimed')
end

local function isTrail(grid, i, j)
    return grid.cells[i] and (grid.cells[i][j] == 'trail')
end

function Player:update(dt, grid)
    -- Character-specific updates
    if self.character and self.character.name == "Trickster" then
        self.tricksterSwapTimer = self.tricksterSwapTimer - dt
        if self.tricksterSwapTimer <= 0 then
            local enemies = grid.enemies -- Assuming enemies are accessible via grid
            if enemies and #enemies > 0 then
                local randomEnemy = enemies[math.random(#enemies)]
                -- Swap positions
                local tempI, tempJ = self.i, self.j
                self.i, self.j = randomEnemy.i, randomEnemy.j
                randomEnemy.i, randomEnemy.j = tempI, tempJ
                self.tricksterSwapTimer = 10 -- Reset timer
                 -- Ensure player is not swapped into a wall/obstacle if those exist
                if not grid:isInside(self.i, self.j) or grid.cells[self.i][self.j] == 'obstacle' then
                    -- Revert swap or find a safe nearby cell (simplified for now)
                    randomEnemy.i, randomEnemy.j = self.i, self.j
                    self.i, self.j = tempI, tempJ
                end
            end
        end
    end

    self.moveTimer = self.moveTimer - dt
    if self.moveTimer <= 0 then
        local dx, dy = 0, 0
        if love.keyboard.isDown('up') then dy = -1 end
        if love.keyboard.isDown('down') then dy = 1 end
        if love.keyboard.isDown('left') then dx = -1 end
        if love.keyboard.isDown('right') then dx = 1 end
        if dx ~= 0 or dy ~= 0 then
            local ni, nj = self.i + dx, self.j + dy
            if grid:isInside(ni, nj) then
                local prevClaimed = isClaimed(grid, self.i, self.j)
                local nextClaimed = isClaimed(grid, ni, nj)
                local nextTrail = isTrail(grid, ni, nj)
                -- מניעת התחלת trail על תא שכבר סגור
                if not self.isDrawing and nextClaimed then
                    self.i, self.j = ni, nj
                    self.moveTimer = self.moveDelay
                    return
                end
                if self.isDrawing and nextTrail then
                    return
                end
                self.i, self.j = ni, nj
                self.moveTimer = self.moveDelay
                if prevClaimed and not nextClaimed then
                    self.isDrawing = true
                    self.trail = {{i=ni, j=nj}}
                    grid.cells[ni][nj] = 'trail'
                elseif self.isDrawing and not nextClaimed then
                    table.insert(self.trail, {i=ni, j=nj})
                    grid.cells[ni][nj] = 'trail'
                elseif self.isDrawing and nextClaimed then
                    self.isDrawing = false
                    if #self.trail > 2 then
                        for _, cell in ipairs(self.trail) do
                            grid.cells[cell.i][cell.j] = 'claimed'
                        end
                        grid:closeArea(self.trail)
                        -- Clean up any leftover trail cells
                        for _, cell in ipairs(self.trail) do
                            grid.cells[cell.i][cell.j] = 'claimed'
                        end
                    end
                    self.trail = {}
                end
            end
        end
    end
end

function Player:draw(grid)
    -- Draw trail
    if not grid._jammedTrail and self.isDrawing and #self.trail > 0 then
        love.graphics.setColor(self.trailColor)
        for _, cell in ipairs(self.trail) do
            local x = grid.offsetX + (cell.i-1)*grid.cellSize
            local y = grid.offsetY + (cell.j-1)*grid.cellSize
            love.graphics.rectangle('fill', x, y, grid.cellSize-1, grid.cellSize-1, 6, 6)
        end
    end
    -- Draw player
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    love.graphics.setColor(self.color)
    love.graphics.circle('fill', x, y, grid.cellSize*0.35)
    love.graphics.setColor(1,1,1)
end

return Player
