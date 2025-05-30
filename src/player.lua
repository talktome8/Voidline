local Player = {}

function Player:load(grid)
    self.i = math.floor(grid.width/2)
    self.j = math.floor(grid.height/2)
    self.moveDelay = 0.12
    self.moveTimer = 0
    self.dir = {x=0, y=0}
    self.trail = {}
    self.isDrawing = false
end

local function isClaimed(grid, i, j)
    return grid.cells[i] and (grid.cells[i][j] == 'claimed')
end

local function isTrail(grid, i, j)
    return grid.cells[i] and (grid.cells[i][j] == 'trail')
end

function Player:update(dt, grid)
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
                -- Prevent moving onto your own trail
                if self.isDrawing and nextTrail then
                    -- Game over logic could go here
                    return
                end
                self.i, self.j = ni, nj
                self.moveTimer = self.moveDelay
                if prevClaimed and not nextClaimed then
                    -- Start trail
                    self.isDrawing = true
                    self.trail = {{i=ni, j=nj}}
                    grid.cells[ni][nj] = 'trail'
                elseif self.isDrawing and not nextClaimed then
                    -- Continue trail
                    table.insert(self.trail, {i=ni, j=nj})
                    grid.cells[ni][nj] = 'trail'
                elseif self.isDrawing and nextClaimed then
                    -- Returned to claimed area: close loop
                    self.isDrawing = false
                    if #self.trail > 2 then
                        for _, cell in ipairs(self.trail) do
                            grid.cells[cell.i][cell.j] = 'claimed'
                        end
                        grid:closeArea(self.trail)
                    end
                    self.trail = {}
                end
            end
        end
    end
end

function Player:draw(grid)
    -- Draw trail
    if self.isDrawing and #self.trail > 0 then
        love.graphics.setColor(1, 0.8, 0.2)
        for _, cell in ipairs(self.trail) do
            local x = grid.offsetX + (cell.i-1)*grid.cellSize
            local y = grid.offsetY + (cell.j-1)*grid.cellSize
            love.graphics.rectangle('fill', x, y, grid.cellSize-1, grid.cellSize-1, 6, 6)
        end
    end
    -- Draw player
    local x = grid.offsetX + (self.i-0.5)*grid.cellSize
    local y = grid.offsetY + (self.j-0.5)*grid.cellSize
    love.graphics.setColor(0.2,0.6,1)
    love.graphics.circle('fill', x, y, grid.cellSize*0.35)
    love.graphics.setColor(1,1,1)
end

return Player
