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
    -- Echo Lab support: after zone closure, briefly revert claimed cells to empty, then re-claim
    if self._echoLabTimer and self._echoLabTimer > 0 then
        self._echoLabTimer = self._echoLabTimer - dt
        if self._echoLabTimer <= 0 and self._echoLabToClaim then
            for _, cell in ipairs(self._echoLabToClaim) do
                self.cells[cell.i][cell.j] = 'claimed'
            end
            self._echoLabToClaim = nil
        end
    end

    -- אפקט jammedTrail: אם הופעל, לא מציגים את ה-trail
    if self._jammedTrail and self._jammedTrail > 0 then
        self._jammedTrail = self._jammedTrail - dt
        if self._jammedTrail < 0 then self._jammedTrail = nil end
    end
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
    local newlyClaimedCellCount = 0 -- Initialize counter

    if not trail or #trail == 0 then 
        return 0  -- Ensure 0 is returned if trail is nil or empty
    end

    -- Always perform classic Qix/Xonix closure, regardless of realm
    local function isTrailOrthogonal(trail_to_check)
        if not trail_to_check or #trail_to_check < 1 then return true end
        if #trail_to_check == 1 then return true end
        for idx = 2, #trail_to_check do
            local prev = trail_to_check[idx-1]
            local curr = trail_to_check[idx]
            local dx = math.abs(curr.i - prev.i)
            local dy = math.abs(curr.j - prev.j)
            if dx + dy ~= 1 then
                return false
            end
        end
        return true
    end
    local function isTrailProperlyClosed(trail_to_check, self_grid)
        if not trail_to_check or #trail_to_check == 0 then return false end
        local head = trail_to_check[#trail_to_check]
        if self_grid:isClaimed(head.i, head.j) then return true end
        local dirs_check = {{1,0},{-1,0},{0,1},{0,-1}}
        for _, d in ipairs(dirs_check) do
            local ni, nj = head.i + d[1], head.j + d[2]
            if self_grid:isClaimed(ni, nj) then
                return true
            end
        end
        return false
    end
    if not trail or #trail == 0 then return end
    if not isTrailOrthogonal(trail) then
        for _, cell_data in ipairs(trail) do
            if self.cells[cell_data.i][cell_data.j] == 'trail' then
                self.cells[cell_data.i][cell_data.j] = 'empty'
            end
        end
        return 0 -- Ensure 0 is returned
    end
    if not isTrailProperlyClosed(trail, self) then
        for _, cell_data in ipairs(trail) do
            if self.cells[cell_data.i][cell_data.j] == 'trail' then
                self.cells[cell_data.i][cell_data.j] = 'empty'
            end
        end
        return 0 -- Ensure 0 is returned
    end
    -- Mark trail as claimed for area detection
    for _, cell_data in ipairs(trail) do
        if self:isInside(cell_data.i, cell_data.j) and self.cells[cell_data.i][cell_data.j] ~= 'claimed' then
            self.cells[cell_data.i][cell_data.j] = 'claimed'
            newlyClaimedCellCount = newlyClaimedCellCount + 1
        end
    end
    -- Flood fill: mark all cells connected to the border as 'outside'
    local visited = {}
    for i=1,self.width do visited[i] = {} for j=1,self.height do visited[i][j] = false end end
    local queue = {}
    for i = 1, self.width do
        for j = 1, self.height do
            if self.cells[i][j] ~= 'claimed' and (i == 1 or i == self.width or j == 1 or j == self.height) then
                table.insert(queue, {i=i, j=j})
                visited[i][j] = true
            end
        end
    end
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    local head_idx = 1
    while head_idx <= #queue do
        local current_cell = queue[head_idx]
        head_idx = head_idx + 1
        for _, d in ipairs(dirs) do
            local ni, nj = current_cell.i + d[1], current_cell.j + d[2]
            if self:isInside(ni, nj) and not visited[ni][nj] and self.cells[ni][nj] ~= 'claimed' then
                visited[ni][nj] = true
                table.insert(queue, {i=ni, j=nj})
            end
        end
    end
    -- Find all closed regions (not visited, not claimed)
    local regionLabels = {}
    local label = 0
    local labelToCells = {}
    local labelHasEnemy = {}
    local enemies = self.enemies or {}
    for i = 2, self.width-1 do
        for j = 2, self.height-1 do
            if not visited[i][j] and self.cells[i][j] ~= 'claimed' and not regionLabels[i..','..j] then
                label = label + 1
                labelToCells[label] = {}
                local queue2 = {{i=i, j=j}}
                regionLabels[i..','..j] = label
                local idx2 = 1
                while idx2 <= #queue2 do
                    local cell = queue2[idx2]
                    idx2 = idx2 + 1
                    table.insert(labelToCells[label], cell)
                    for _, enemy in ipairs(enemies) do
                        if enemy.i == cell.i and enemy.j == cell.j then
                            labelHasEnemy[label] = true
                        end
                    end
                    for _, d in ipairs(dirs) do
                        local ni, nj = cell.i + d[1], cell.j + d[2]
                        if ni >= 2 and ni <= self.width-1 and nj >= 2 and nj <= self.height-1 then
                            if not visited[ni][nj] and self.cells[ni][nj] ~= 'claimed' and not regionLabels[ni..','..nj] then
                                regionLabels[ni..','..nj] = label
                                table.insert(queue2, {i=ni, j=nj})
                            end
                        end
                    end
                end
            end
        end
    end
    -- Claim all closed regions with no enemy
    for lbl, cells in pairs(labelToCells) do
        if not labelHasEnemy[lbl] then
            for _, cell in ipairs(cells) do
                if self.cells[cell.i] and self.cells[cell.i][cell.j] and self.cells[cell.i][cell.j] ~= 'claimed' then
                    self.cells[cell.i][cell.j] = 'claimed'
                    newlyClaimedCellCount = newlyClaimedCellCount + 1
                end
            end
        end
    end
    -- Always ensure the border is claimed
    for i = 1, self.width do
        self.cells[i][1] = 'claimed'
        self.cells[i][self.height] = 'claimed'
    end
    for j = 1, self.height do
        self.cells[1][j] = 'claimed'
        self.cells[self.width][j] = 'claimed'
    end
    -- Always clean up trail (ensure they are marked claimed, count already handled)
    for _, cell_data in ipairs(trail) do
        if self:isInside(cell_data.i, cell_data.j) and self.cells[cell_data.i][cell_data.j] ~= 'claimed' then
            -- This case should ideally not happen if trail marking above was comprehensive
            -- but as a safeguard:
            self.cells[cell_data.i][cell_data.j] = 'claimed'
            newlyClaimedCellCount = newlyClaimedCellCount + 1
        elseif self:isInside(cell_data.i, cell_data.j) and self.cells[cell_data.i][cell_data.j] == 'trail' then
             -- If it was still 'trail', ensure it's 'claimed'. Counted when first turned to 'claimed'.
            self.cells[cell_data.i][cell_data.j] = 'claimed'
        end
    end
    return newlyClaimedCellCount -- Return the count
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
    if total == 0 then return 0 end -- Avoid division by zero
    return claimed / total
end

function Grid:addBonusClaimedCells(bonusCells)
    if not bonusCells or #bonusCells == 0 then
        return 0
    end
    local actuallyClaimedCount = 0
    for _, cell in ipairs(bonusCells) do
        if self:isInside(cell.i, cell.j) and self.cells[cell.i][cell.j] ~= 'claimed' then
            self.cells[cell.i][cell.j] = 'claimed'
            actuallyClaimedCount = actuallyClaimedCount + 1
        end
    end
    return actuallyClaimedCount
end

return Grid
