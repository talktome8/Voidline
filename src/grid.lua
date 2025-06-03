local love = require "love"
local Grid = {}

Grid.width = 24
Grid.height = 16
Grid.cellSize = 32
Grid.cells = {}
Grid.nodeWidth = 0 -- Will be self.width + 1
Grid.nodeHeight = 0 -- Will be self.height + 1

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
    self.nodeWidth = self.width + 1
    self.nodeHeight = self.height + 1
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
    -- Recently claimed highlight effect
    if self._recentlyClaimedTimer and self._recentlyClaimedTimer > 0 then
        self._recentlyClaimedTimer = self._recentlyClaimedTimer - dt
        if self._recentlyClaimedTimer <= 0 then
            self._recentlyClaimedCells = nil
            self._recentlyClaimedTimer = 0
        end
    end
end

function Grid:draw()
    -- Protection: If the grid is not initialized, do not draw
    if not self.cells or not self.cells[1] then return end
    -- Draw Cells
    for i = 1, self.width do
        for j = 1, self.height do
            local cellType = self.cells[i] and self.cells[i][j] or 'empty'
            local color = cellColors[cellType] or {1,1,1}
            local x = self.offsetX + (i-1)*self.cellSize
            local y = self.offsetY + (j-1)*self.cellSize
            local highlight = false
            if self._recentlyClaimedCells then
                for _, cell in ipairs(self._recentlyClaimedCells) do
                    if cell.i == i and cell.j == j then
                        highlight = true
                        break
                    end
                end
            end
            if highlight then
                local t = math.max(0, self._recentlyClaimedTimer or 0) / (self._recentlyClaimedDuration or 1)
                love.graphics.setColor(color[1]+0.5*t, color[2]+0.5*t, color[3]+0.5*t, 1)
            else
                love.graphics.setColor(color)
            end
            love.graphics.rectangle('fill', x, y, self.cellSize-1, self.cellSize-1, 6, 6)
        end
    end
    love.graphics.setColor(1,1,1)

    -- Optional: Draw nodes for debugging
    -- love.graphics.setColor(0.5, 0.5, 0.5, 0.5) -- Light gray for nodes
    -- for ni = 1, self.nodeWidth do
    --     for nj = 1, self.nodeHeight do
    --         local px, py = self:getNodePixelPosition(ni, nj)
    --         love.graphics.circle('fill', px, py, 2)
    --     end
    -- end
    -- love.graphics.setColor(1,1,1)
end

-- Convert node coordinates to pixel coordinates
function Grid:getNodePixelPosition(node_i, node_j)
    if not self.offsetX or not self.offsetY or not self.cellSize then
        print("Error: Grid offset or cellSize not initialized before getNodePixelPosition call.")
        return 0, 0 -- Return a default or handle error appropriately
    end
    -- Nodes are at the corners of cells. Node (1,1) is top-left of cell (1,1).
    -- Pixel position is offsetX + (node_index - 1) * cellSize
    local px = self.offsetX + (node_i - 1) * self.cellSize
    local py = self.offsetY + (node_j - 1) * self.cellSize
    return px, py
end

function Grid:closeArea(trail)
    -- This function currently expects a cell-based trail.
    -- It will need to be replaced or heavily modified for node-based trails.
    -- For now, it might misbehave if called with a node-based trail.
    print("Grid:closeArea called. WARNING: This function is designed for cell-based trails and may not work correctly with node-based trails yet.")
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
            -- Allow orthogonal (dx+dy == 1) or diagonal (dx==1 and dy==1)
            if not ((dx + dy == 1) or (dx == 1 and dy == 1)) then
                return false
            end
        end
        return true
    end
    local function isTrailProperlyClosed(trail)
        if #trail < 3 then
            return false
        end
        return true
    end
    if not trail or #trail == 0 then return 0 end -- Ensure 0 is returned
    if not isTrailOrthogonal(trail) then
        for _, cell_data in ipairs(trail) do
            if self:isInside(cell_data.i, cell_data.j) and self.cells[cell_data.i][cell_data.j] == 'trail' then
                self.cells[cell_data.i][cell_data.j] = 'empty'
            end
        end
        return 0 -- Ensure 0 is returned
    end
    if not isTrailProperlyClosed(trail) then
        for _, cell_data in ipairs(trail) do
            if self:isInside(cell_data.i, cell_data.j) and self.cells[cell_data.i][cell_data.j] == 'trail' then
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

    local visited = {}
    for i=1,self.width do visited[i] = {} for j=1,self.height do visited[i][j] = false end end
    local queue = {}
    for i = 1, self.width do
        for j = 1, self.height do
            if (i == 1 or i == self.width or j == 1 or j == self.height) and self.cells[i][j] ~= 'claimed' then
                table.insert(queue, {i=i, j=j})
                visited[i][j] = true
            elseif self.cells[i][j] ~= 'claimed' and (i == 1 or i == self.width or j == 1 or j == self.height) then
                 table.insert(queue, {i=i, j=j})
                 visited[i][j] = true
            end
        end
    end

    local dirs_outside_check = {{1,0},{-1,0},{0,1},{0,-1}}
    local head_idx = 1
    while head_idx <= #queue do
        local current_cell = queue[head_idx]
        head_idx = head_idx + 1
        for _, d in ipairs(dirs_outside_check) do
            local ni, nj = current_cell.i + d[1], current_cell.j + d[2]
            if self:isInside(ni, nj) and not visited[ni][nj] and self.cells[ni][nj] ~= 'claimed' then
                visited[ni][nj] = true
                table.insert(queue, {i=ni, j=nj})
            end
        end
    end

    local regionLabels = {}
    local label = 0
    local labelToCells = {}
    local labelHasEnemy = {}
    local enemies = self.enemies or {}
    local dirs_region_fill = {{1,0},{-1,0},{0,1},{0,-1}, {1,1}, {1,-1}, {-1,1}, {-1,-1}}

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
                    for _, d in ipairs(dirs_region_fill) do
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
    for i = 1, self.width do
        self.cells[i][1] = 'claimed'
        self.cells[i][self.height] = 'claimed'
    end
    for j = 1, self.height do
        self.cells[1][j] = 'claimed'
        self.cells[self.width][j] = 'claimed'
    end
    for _, cell_data in ipairs(trail) do
        if self:isInside(cell_data.i, cell_data.j) and self.cells[cell_data.i][cell_data.j] ~= 'claimed' then
            self.cells[cell_data.i][cell_data.j] = 'claimed'
            newlyClaimedCellCount = newlyClaimedCellCount + 1
        elseif self:isInside(cell_data.i, cell_data.j) and self.cells[cell_data.i][cell_data.j] == 'trail' then
            self.cells[cell_data.i][cell_data.j] = 'claimed'
        end
    end
    return newlyClaimedCellCount
end

function Grid:closeAreaByNodes(nodeTrail, player)
    if not nodeTrail or #nodeTrail < 3 then return 0 end
    local newlyClaimedCellCount = 0
    local visited = {}
    for i = 1, self.width do visited[i] = {} end
    local q = {}
    -- 1. סימון כל התאים שמחוברים לגבול או לאויבים (כל מה שלא אמור להיצבע)
    if self.enemies and #self.enemies > 0 then
        for _, enemy in ipairs(self.enemies) do
            if self:isInside(enemy.i, enemy.j) then
                table.insert(q, {i=enemy.i, j=enemy.j})
                visited[enemy.i][enemy.j] = true
            end
        end
    end
    -- אם אין אויבים, התחל מהגבול
    if #q == 0 then
        for i = 1, self.width do
            if self:isInside(i,1) then table.insert(q, {i=i, j=1}); visited[i][1] = true end
            if self:isInside(i,self.height) then table.insert(q, {i=i, j=self.height}); visited[i][self.height] = true end
        end
        for j = 2, self.height-1 do
            if self:isInside(1,j) then table.insert(q, {i=1, j=j}); visited[1][j] = true end
            if self:isInside(self.width,j) then table.insert(q, {i=self.width, j=j}); visited[self.width][j] = true end
        end
    end
    -- 1.5: סימון כל תאי השובל כגבול (לא ייצבעו)
    for _, node in ipairs(nodeTrail) do
        local ci, cj = node.i, node.j
        if self:isInside(ci, cj) then
            visited[ci][cj] = true
        end
    end
    -- 2. BFS: כל תא שמגיעים אליו מהגבול/אויבים/שובל מסומן כלא להיצבע
    local head = 1
    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    while head <= #q do
        local curr = q[head]
        head = head + 1
        for _, d in ipairs(dirs) do
            local ni, nj = curr.i + d[1], curr.j + d[2]
            if self:isInside(ni, nj) and not visited[ni][nj] and self.cells[ni][nj] ~= 'claimed' then
                visited[ni][nj] = true
                table.insert(q, {i=ni, j=nj})
            end
        end
    end
    -- 3. כל תא שלא ב-visited ולא ב-claimed - הוא אזור סגור! נצבע אותו
    local closedCells = {}
    for i = 2, self.width-1 do
        for j = 2, self.height-1 do
            if not visited[i][j] and self.cells[i][j] ~= 'claimed' then
                self.cells[i][j] = 'claimed'
                newlyClaimedCellCount = newlyClaimedCellCount + 1
                table.insert(closedCells, {i=i, j=j})
            end
        end
    end
    -- 4. אפקט ויזואלי לאזור שנסגר
    self._recentlyClaimedCells = closedCells
    self._recentlyClaimedTimer = self._recentlyClaimedDuration or 0.4
    -- 5. נצבע גם את ה-trail עצמו
    for _, node in ipairs(nodeTrail) do
        local ci, cj = node.i, node.j
        if self:isInside(ci, cj) and self.cells[ci][cj] ~= 'claimed' then
            self.cells[ci][cj] = 'claimed'
        end
    end
    return newlyClaimedCellCount
end

-- Convert node coordinates to pixel coordinates
function Grid:getNodePixelPosition(node_i, node_j)
    if not self.offsetX or not self.offsetY or not self.cellSize then
        print("Error: Grid offset or cellSize not initialized before getNodePixelPosition call.")
        return 0, 0 -- Return a default or handle error appropriately
    end
    -- Nodes are at the corners of cells. Node (1,1) is top-left of cell (1,1).
    -- Pixel position is offsetX + (node_index - 1) * cellSize
    local px = self.offsetX + (node_i - 1) * self.cellSize
    local py = self.offsetY + (node_j - 1) * self.cellSize
    return px, py
end

function Grid:closeArea(trail)
    -- This function currently expects a cell-based trail.
    -- It will need to be replaced or heavily modified for node-based trails.
    -- For now, it might misbehave if called with a node-based trail.
    print("Grid:closeArea called. WARNING: This function is designed for cell-based trails and may not work correctly with node-based trails yet.")
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
            -- Allow orthogonal (dx+dy == 1) or diagonal (dx==1 and dy==1)
            if not ((dx + dy == 1) or (dx == 1 and dy == 1)) then
                return false
            end
        end
        return true
    end
    local function isTrailProperlyClosed(trail)
        if #trail < 3 then
            return false
        end
        return true
    end
    if not trail or #trail == 0 then return 0 end -- Ensure 0 is returned
    if not isTrailOrthogonal(trail) then
        for _, cell_data in ipairs(trail) do
            if self:isInside(cell_data.i, cell_data.j) and self.cells[cell_data.i][cell_data.j] == 'trail' then
                self.cells[cell_data.i][cell_data.j] = 'empty'
            end
        end
        return 0 -- Ensure 0 is returned
    end
    if not isTrailProperlyClosed(trail) then
        for _, cell_data in ipairs(trail) do
            if self:isInside(cell_data.i, cell_data.j) and self.cells[cell_data.i][cell_data.j] == 'trail' then
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

    local visited = {}
    for i=1,self.width do visited[i] = {} for j=1,self.height do visited[i][j] = false end end
    local queue = {}
    for i = 1, self.width do
        for j = 1, self.height do
            if (i == 1 or i == self.width or j == 1 or j == self.height) and self.cells[i][j] ~= 'claimed' then
                table.insert(queue, {i=i, j=j})
                visited[i][j] = true
            elseif self.cells[i][j] ~= 'claimed' and (i == 1 or i == self.width or j == 1 or j == self.height) then
                 table.insert(queue, {i=i, j=j})
                 visited[i][j] = true
            end
        end
    end

    local dirs_outside_check = {{1,0},{-1,0},{0,1},{0,-1}}
    local head_idx = 1
    while head_idx <= #queue do
        local current_cell = queue[head_idx]
        head_idx = head_idx + 1
        for _, d in ipairs(dirs_outside_check) do
            local ni, nj = current_cell.i + d[1], current_cell.j + d[2]
            if self:isInside(ni, nj) and not visited[ni][nj] and self.cells[ni][nj] ~= 'claimed' then
                visited[ni][nj] = true
                table.insert(queue, {i=ni, j=nj})
            end
        end
    end

    local regionLabels = {}
    local label = 0
    local labelToCells = {}
    local labelHasEnemy = {}
    local enemies = self.enemies or {}
    local dirs_region_fill = {{1,0},{-1,0},{0,1},{0,-1}, {1,1}, {1,-1}, {-1,1}, {-1,-1}}

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
                    for _, d in ipairs(dirs_region_fill) do
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
    for i = 1, self.width do
        self.cells[i][1] = 'claimed'
        self.cells[i][self.height] = 'claimed'
    end
    for j = 1, self.height do
        self.cells[1][j] = 'claimed'
        self.cells[self.width][j] = 'claimed'
    end
    for _, cell_data in ipairs(trail) do
        if self:isInside(cell_data.i, cell_data.j) and self.cells[cell_data.i][cell_data.j] ~= 'claimed' then
            self.cells[cell_data.i][cell_data.j] = 'claimed'
            newlyClaimedCellCount = newlyClaimedCellCount + 1
        elseif self:isInside(cell_data.i, cell_data.j) and self.cells[cell_data.i][cell_data.j] == 'trail' then
            self.cells[cell_data.i][cell_data.j] = 'claimed'
        end
    end
    return newlyClaimedCellCount
end

-- Checks if a trail segment (n1-n2) blocks movement between cell C1 and cell C2.
-- C1 and C2 are defined by their integer coordinates (c1_i, c1_j) and (c2_i, c2_j).
-- Movement between C1 and C2 is assumed to be orthogonal.
function Grid:isTrailSegmentBetween(n1, n2, c1_i, c1_j, c2_i, c2_j)
    -- Remove all print statements from this function for performance
    if (n1.i == n2.i and n1.j == n2.j) then
        return false
    end
    local cell_move_horizontal = (c1_j == c2_j)
    local cell_move_vertical = (c1_i == c2_i)
    local trail_seg_horizontal = (n1.j == n2.j)
    local trail_seg_vertical = (n1.i == n2.i)
    local trail_seg_diagonal = (math.abs(n1.i - n2.i) == 1 and math.abs(n1.j - n2.j) == 1)
    local p1_i, p1_j, p2_i, p2_j
    if cell_move_horizontal then
        p1_i = math.max(c1_i, c2_i); p1_j = c1_j;
        p2_i = math.max(c1_i, c2_i); p2_j = c1_j + 1;
    elseif cell_move_vertical then
        p1_i = c1_i;       p1_j = math.max(c1_j, c2_j);
        p2_i = c1_i + 1;   p2_j = math.max(c1_j, c2_j);
    else
        return false
    end
    if (trail_seg_horizontal and cell_move_vertical) or (trail_seg_vertical and cell_move_horizontal) then
        if trail_seg_vertical then
            if n1.i == p1_i then
                local y_trail_min = math.min(n1.j, n2.j)
                local y_trail_max = math.max(n1.j, n2.j)
                local y_interface_min = math.min(p1_j, p2_j)
                local y_interface_max = math.max(p1_j, p2_j)
                if math.max(y_trail_min, y_interface_min) < math.min(y_trail_max, y_interface_max) then
                    return true
                end
            end
        elseif trail_seg_horizontal then
            if n1.j == p1_j then
                local x_trail_min = math.min(n1.i, n2.i)
                local x_trail_max = math.max(n1.i, n2.i)
                local x_interface_min = math.min(p1_i, p2_i)
                local x_interface_max = math.max(p1_i, p2_i)
                if math.max(x_trail_min, x_interface_min) < math.min(x_trail_max, x_interface_max) then
                    return true
                end
            end
        end
    elseif (trail_seg_vertical and cell_move_vertical) or (trail_seg_horizontal and cell_move_horizontal) then
        local intersection_node_i, intersection_node_j
        if trail_seg_vertical then
            intersection_node_i = n1.i
            intersection_node_j = p1_j
            local min_ny = math.min(n1.j, n2.j)
            local max_ny = math.max(n1.j, n2.j)
            local min_px = math.min(p1_i, p2_i)
            local max_px = math.max(p1_i, p2_i)
            if intersection_node_i >= min_px and intersection_node_i <= max_px and
               intersection_node_j >= min_ny and intersection_node_j <= max_ny then
                return true
            end
        else
            intersection_node_i = p1_i
            intersection_node_j = n1.j
            local min_nx = math.min(n1.i, n2.i)
            local max_nx = math.max(n1.i, n2.i)
            local min_py = math.min(p1_j, p2_j)
            local max_py = math.max(p1_j, p2_j)
            if intersection_node_j >= min_py and intersection_node_j <= max_py and
               intersection_node_i >= min_nx and intersection_node_i <= max_nx then
                return true
            end
        end
    end
    if trail_seg_diagonal then
        local shared_node_i, shared_node_j
        local other_trail_node_i, other_trail_node_j
        local other_interface_node_i, other_interface_node_j
        local found_shared_node = false
        if n1.i == p1_i and n1.j == p1_j then
            shared_node_i, shared_node_j = n1.i, n1.j; other_trail_node_i, other_trail_node_j = n2.i, n2.j; other_interface_node_i, other_interface_node_j = p2_i, p2_j; found_shared_node = true;
        elseif n1.i == p2_i and n1.j == p2_j then
            shared_node_i, shared_node_j = n1.i, n1.j; other_trail_node_i, other_trail_node_j = n2.i, n2.j; other_interface_node_i, other_interface_node_j = p1_i, p1_j; found_shared_node = true;
        elseif n2.i == p1_i and n2.j == p1_j then
            shared_node_i, shared_node_j = n2.i, n2.j; other_trail_node_i, other_trail_node_j = n1.i, n1.j; other_interface_node_i, other_interface_node_j = p2_i, p2_j; found_shared_node = true;
        elseif n2.i == p2_i and n2.j == p2_j then
            shared_node_i, shared_node_j = n2.i, n2.j; other_trail_node_i, other_trail_node_j = n1.i, n1.j; other_interface_node_i, other_interface_node_j = p1_i, p1_j; found_shared_node = true;
        end
        if found_shared_node then
            local v_trail_i = other_trail_node_i - shared_node_i
            local v_trail_j = other_trail_node_j - shared_node_j
            local v_interface_i = other_interface_node_i - shared_node_i
            local v_interface_j = other_interface_node_j - shared_node_j
            local cross_product = (v_trail_i * v_interface_j - v_trail_j * v_interface_i)
            if cross_product ~= 0 then
                return true
            end
        end
    end
    return false
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

-- Set required percent for win (per level)
Grid.requiredClaimedPercent = 0.5
function Grid:setRequiredClaimedPercent(p)
    self.requiredClaimedPercent = p
end

-- Dynamically set grid size to fit window
function Grid:setSizeToWindow(ww, wh, margin)
    margin = margin or 32 -- Default margin if not provided
    local availableWidth = ww - 2 * margin
    local availableHeight = wh - 2 * margin

    -- Determine cell size based on a target number of cells (e.g., 32x20 or 24x16)
    -- Let's aim for something like 24 width and 16 height as a base, adjust if too small
    local targetGridW = 24
    local targetGridH = 16

    local csW = math.floor(availableWidth / targetGridW)
    local csH = math.floor(availableHeight / targetGridH)
    
    self.cellSize = math.max(16, math.min(csW, csH)) -- Ensure cellSize is at least, say, 16

    self.width = math.floor(availableWidth / self.cellSize)
    self.height = math.floor(availableHeight / self.cellSize)

    self.nodeWidth = self.width + 1
    self.nodeHeight = self.height + 1

    -- Recalculate actual margins to center the grid
    local actualGridPixelWidth = self.width * self.cellSize
    local actualGridPixelHeight = self.height * self.cellSize
    self.offsetX = math.floor((ww - actualGridPixelWidth) / 2)
    self.offsetY = math.floor((wh - actualGridPixelHeight) / 2)
end

function Grid:getClaimedPercent()
    local claimed, total = 0, 0
    if not self.cells or not self.width or not self.height then -- Guard clause
        print("Error in Grid:getClaimedPercent - grid not properly initialized (cells, width, or height is nil)")
        if not self.cells then print("self.cells is nil") end
        if not self.width then print("self.width is nil") end
        if not self.height then print("self.height is nil") end
        return 0
    end
    for i = 2, self.width-1 do
        if self.cells[i] == nil then -- Guard for row
            print("Warning in Grid:getClaimedPercent - self.cells[" .. i .. "] is nil. Grid width: " .. self.width)
            goto continue_outer_loop -- Skip this iteration
        end
        for j = 2, self.height-1 do
            total = total + 1
            if self.cells[i][j] == nil then -- Guard for cell
                print("Warning in Grid:getClaimedPercent - self.cells[" .. i .. "][" .. j .. "] is nil. Grid height: " .. self.height)
                goto continue_inner_loop -- Skip this iteration
            end
            if self.cells[i][j] == 'claimed' then
                claimed = claimed + 1
            end
            ::continue_inner_loop::
        end
        ::continue_outer_loop::
    end
    if total == 0 then return 0 end -- Avoid division by zero
    return claimed / total
end

function Grid:isNodeValid(node_i, node_j)
    if not self.nodeWidth or not self.nodeHeight then
        print("Error: Grid nodeWidth or nodeHeight not initialized before isNodeValid call.")
        return false
    end
    return node_i >= 1 and node_i <= self.nodeWidth and node_j >= 1 and node_j <= self.nodeHeight
end

-- Ensure Grid:isNodeValid is defined before this point.

function Grid:isLineSafe(prev_node_i, prev_node_j, next_node_i, next_node_j)
    if not self.nodeWidth or not self.nodeHeight or not self.width or not self.height then
        print("Error: Grid dimensions not initialized before isLineSafe call.")
        return false
    end

    -- Horizontal segment
    if prev_node_j == next_node_j then
        local node_j = prev_node_j
        -- Check if it's a segment on the top or bottom border of the node grid
        if node_j == 1 or node_j == self.nodeHeight then
            return true -- Segments on the absolute top/bottom node lines are part of the border
        end

        -- For internal horizontal node lines, check cells above and below
        local cell_i_idx = math.min(prev_node_i, next_node_i)
        local cell_above_ok = self:isInside(cell_i_idx, node_j - 1) and self:isClaimed(cell_i_idx, node_j - 1)
        local cell_below_ok = self:isInside(cell_i_idx, node_j)     and self:isClaimed(cell_i_idx, node_j)
        return cell_above_ok and cell_below_ok

    -- Vertical segment
    elseif prev_node_i == next_node_i then
        local node_i = prev_node_i
        -- Check if it's a segment on the left or right border of the node grid
        if node_i == 1 or node_i == self.nodeWidth then
            return true -- Segments on the absolute left/right node lines are part of the border
        end

        -- For internal vertical node lines, check cells to the left and right
        local cell_j_idx = math.min(prev_node_j, next_node_j)
        local cell_left_ok  = self:isInside(node_i - 1, cell_j_idx) and self:isClaimed(node_i - 1, cell_j_idx)
        local cell_right_ok = self:isInside(node_i, cell_j_idx)     and self:isClaimed(node_i, cell_j_idx)
        return cell_left_ok and cell_right_ok
    end

    -- Should not happen for orthogonal movement
    print(string.format("Warning: isLineSafe called with non-orthogonal or zero-length segment N(%d,%d)-N(%d,%d)", prev_node_i, prev_node_j, next_node_i, next_node_j))
    return false
end

-- Highlight effect for recently claimed cells
Grid._recentlyClaimedCells = nil
Grid._recentlyClaimedTimer = 0
Grid._recentlyClaimedDuration = 0.4

return Grid
