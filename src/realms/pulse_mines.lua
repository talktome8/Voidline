local PulseMines = {}

function PulseMines:load(Grid, Player)
    self.mines = {}
    local mineCount = math.max(3, math.floor(Grid.width * Grid.height * 0.03))
    for _ = 1, mineCount do
        local i = math.random(2, Grid.width-1)
        local j = math.random(2, Grid.height-1)
        table.insert(self.mines, {i=i, j=j})
    end
    -- Load assets specific to Pulse Mines realm
    -- Initialize realm-specific variables
    print("Pulse Mines Realm Loaded")
end

function PulseMines:update(dt, Grid, Player)
    for _, mine in ipairs(self.mines or {}) do
        if Player.i == mine.i and Player.j == mine.j and not Player.isFuseActive then
            Player.isFuseActive = true
            Player.fuseTimer = Player.fuseDuration
            Player.burningTrail = nil -- No trail, just instant fuse
            Player.fuseHitSegmentIndex = nil
            -- TODO: add sound/visual feedback for mine
        end
    end
    -- Update logic for Pulse Mines
    -- Implement timed shockwaves
end

function PulseMines:draw(Grid)
    for _, mine in ipairs(self.mines or {}) do
        local x = Grid.offsetX + (mine.i-1)*Grid.cellSize
        local y = Grid.offsetY + (mine.j-1)*Grid.cellSize
        love.graphics.setColor(1, 1, 0.2, 0.7)
        love.graphics.circle('fill', x+Grid.cellSize/2, y+Grid.cellSize/2, Grid.cellSize*0.18)
        love.graphics.setColor(1,1,1)
    end
    -- Draw elements specific to Pulse Mines
    -- Visualize shockwaves
end

return PulseMines
