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
            love.graphics.rectangle('fill', (i-1)*self.cellSize, (j-1)*self.cellSize, self.cellSize-1, self.cellSize-1, 6, 6)
        end
    end
    love.graphics.setColor(1,1,1)
end

function Grid:closeArea(trail)
    -- 1. Create a mask for unchecked cells (false)
    local mask = {}
    for i=1,self.width do
        mask[i] = {}
        for j=1,self.height do
            mask[i][j] = false
        end
    end
    -- 2. Mark all trail cells as true in the mask and as claimed
    for _, cell in ipairs(trail) do
        mask[cell.i][cell.j] = true
        self.cells[cell.i][cell.j] = 'claimed'
    end
    -- 3. Flood fill from the borders (all edge cells that are not trail)
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
    -- 4. Any cell not marked in mask is captured (claimed)
    for i=1,self.width do
        for j=1,self.height do
            if not mask[i][j] then
                self.cells[i][j] = 'claimed'
            end
        end
    end
end

return Grid
