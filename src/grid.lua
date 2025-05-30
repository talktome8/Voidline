local Grid = {}

Grid.width = 24
Grid.height = 16
Grid.cellSize = 32
Grid.cells = {}

local cellColors = {
    empty  = {0.12, 0.12, 0.18},
    claimed = {0.2, 0.7, 0.3},
    trail  = {1, 0.8, 0.2},
    enemy  = {0.8, 0.2, 0.2},
}

-- Check if a cell is inside the grid boundaries
function Grid:isInside(i, j)
    return i >= 1 and i <= self.width and j >= 1 and j <= self.height
end

-- Check if a cell is claimed
function Grid:isClaimed(i, j)
    return self.cells[i] and self.cells[i][j] == 'claimed'
end

function Grid:load()
    for i = 1, self.width do
        self.cells[i] = {}
        for j = 1, self.height do
            if i == 1 or i == self.width or j == 1 or j == self.height then
                self.cells[i][j] = 'claimed' -- Borders are always "claimed"
            else
                self.cells[i][j] = 'empty'
            end
        end
    end
end

function Grid:update(dt)
    -- Future: Update enemies, trail, etc.
end

function Grid:draw()
    -- Protection: If the grid is not initialized, do not draw
    if not self.cells or not self.cells[1] then return end
    for i = 1, self.width do
        for j = 1, self.height do
            local cellType = self.cells[i] and self.cells[i][j] or 'empty'
            local color = cellColors[cellType] or {1,1,1}
            love.graphics.setColor(color)
            local x = self.offsetX + (i-1)*self.cellSize
            local y = self.offsetY + (j-1)*self.cellSize
            love.graphics.rectangle('fill', x, y, self.cellSize-1, self.cellSize-1, 6, 6)
        end
    end
    love.graphics.setColor(1,1,1)
end

function Grid:closeArea(trail)
    -- Mark all trail cells as claimed first
    for _, cell in ipairs(trail) do
        self.cells[cell.i][cell.j] = 'claimed'
    end
    -- Flood fill to find all cells to claim
    local mask = {}
    for i=1,self.width do
        mask[i] = {}
        for j=1,self.height do
            mask[i][j] = false
        end
    end
    for _, cell in ipairs(trail) do
        mask[cell.i][cell.j] = true
    end
    local queue = {}
    for i=1,self.width do
        for j=1,self.height do
            if (i==1 or i==self.width or j==1 or j==self.height) and not mask[i][j] then
                table.insert(queue, {i=i, j=j})
                mask[i][j] = true
            end
        end
    end
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    while #queue > 0 do
        local cell = table.remove(queue, 1)
        for _, d in ipairs(dirs) do
            local ni, nj = cell.i + d[1], cell.j + d[2]
            if ni>=1 and ni<=self.width and nj>=1 and nj<=self.height then
                if not mask[ni][nj] and self.cells[ni][nj] ~= 'trail' then
                    mask[ni][nj] = true
                    table.insert(queue, {i=ni, j=nj})
                end
            end
        end
    end
    for i=1,self.width do
        for j=1,self.height do
            if not mask[i][j] then
                self.cells[i][j] = 'claimed'
            end
        end
    end
end

-- Set required percent for win (per level)
Grid.requiredClaimedPercent = 0.5
function Grid:setRequiredClaimedPercent(p)
    self.requiredClaimedPercent = p
end

-- Dynamically set grid size to fit window
function Grid:setSizeToWindow(windowWidth, windowHeight, margin)
    margin = margin or 32
    local cellW = math.floor((windowWidth - 2*margin) / self.width)
    local cellH = math.floor((windowHeight - 2*margin) / self.height)
    self.cellSize = math.min(cellW, cellH)
    self.offsetX = math.floor((windowWidth - self.width*self.cellSize)/2)
    self.offsetY = math.floor((windowHeight - self.height*self.cellSize)/2)
end

function Grid:getClaimedPercent()
    local claimed, total = 0, 0
    for i = 2, self.width-1 do
        for j = 2, self.height-1 do
            total = total + 1
            if self.cells[i][j] == 'claimed' then
                claimed = claimed + 1
            end
        end
    end
    return claimed / total
end

return Grid
