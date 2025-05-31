local EchoLab = {}

EchoLab.name = "Echo Lab"
EchoLab.description = "Zones close, re-open briefly, then reclose (echo effect)."

function EchoLab:load()
    -- Initialize any EchoLab specific variables if needed when a game/level starts with this realm
    self._echoLabTimer = nil
    self._echoLabToClaim = nil
    self._gridRef = nil -- To store reference to the grid object
end

-- The update function now accepts dt and the grid object
function EchoLab:update(dt, grid)
    if not self._gridRef then -- Store grid reference if not already stored
        self._gridRef = grid
    end

    if self._echoLabTimer and self._gridRef then -- Ensure grid reference exists
        self._echoLabTimer = self._echoLabTimer - dt
        if self._echoLabTimer <= 0 then
            for _, cell_coord in ipairs(self._echoLabToClaim) do
                -- Use the stored grid reference to access cells
                if self._gridRef.cells[cell_coord.i] and self._gridRef.cells[cell_coord.i][cell_coord.j] then
                    self._gridRef.cells[cell_coord.i][cell_coord.j] = 'claimed'
                end
            end
            self._echoLabTimer = nil
            self._echoLabToClaim = nil
        end
    end
end

function EchoLab:draw()
end

-- onZoneClosed now accepts the grid object
function EchoLab:onZoneClosed(grid)
    if not self._gridRef then self._gridRef = grid end -- Ensure grid reference

    self._echoLabToClaim = {}
    for i=1, grid.width do
        for j=1, grid.height do
            if grid.cells[i][j] == 'claimed' then
                table.insert(self._echoLabToClaim, {i=i, j=j})
                grid.cells[i][j] = 'empty' -- Re-open briefly
            end
        end
    end
    self._echoLabTimer = 0.5 -- Time before re-closing, adjust as needed
end

return EchoLab
