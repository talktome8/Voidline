-- src/ui/shape_panel.lua
local ShapePanel = {}

function ShapePanel:new(opts)
    local o = {}
    setmetatable(o, { __index = self })
    o.x = (opts and opts.x) or (love.graphics.getWidth() - 220)
    o.y = (opts and opts.y) or 20
    o.w = (opts and opts.w) or 200
    o.h = (opts and opts.h) or 220
    o.font = (opts and opts.font) or love.graphics.newFont(14)
    o.colors = (opts and opts.colors) or {
        panelBg = {0.08, 0.09, 0.12, 0.85},
        panelBorder = {0.35, 0.4, 0.55, 1.0},
        stroke = {0.4, 0.8, 1.0, 1.0}, -- #66CCFF approx
        success = {0.15, 0.82, 0.49, 1.0}, -- #26D07C approx
        text = {1,1,1,1},
        starFilled = {1.0, 0.9, 0.2, 1.0},
        starEmpty = {0.4, 0.4, 0.45, 0.8}
    }
    o.template = { name = "", required = 80, points = {} }
    o.accuracy = 0
    o.stars = 0
    o.starsTarget = 3
    o.flashT = 0 -- success flash timer
    o.stats = nil -- aggregated stats from game
    return o
end

function ShapePanel:setTemplate(name, points, requiredAccuracy)
    self.template.name = name or ""
    self.template.points = points or {}
    self.template.required = requiredAccuracy or 80
end

function ShapePanel:setProgress(accuracy, stars, totalRequiredStars)
    self.accuracy = accuracy or 0
    self.stars = math.max(0, math.floor(stars or 0))
    self.starsTarget = totalRequiredStars or self.starsTarget
end

function ShapePanel:flashSuccess()
    self.flashT = 0.3 -- brief glow
end

function ShapePanel:setStats(stats)
    -- stats: {level, target, requiredAcc, claimed, requiredClaimed, shapeAcc, lives, enemies, time, score, combo}
    self.stats = stats
end

function ShapePanel:update(dt)
    if self.flashT > 0 then
        self.flashT = math.max(0, self.flashT - dt)
    end
end

local function drawStar(cx, cy, r)
    local pts = {}
    local inner = r * 0.5
    for i=0,9 do
        local a = (i/10) * math.pi * 2 - math.pi/2
        local rr = (i % 2 == 0) and r or inner
        table.insert(pts, cx + math.cos(a)*rr)
        table.insert(pts, cy + math.sin(a)*rr)
    end
    love.graphics.polygon('fill', pts)
end

function ShapePanel:draw()
    local x,y,w,h = self.x, self.y, self.w, self.h
    -- Panel
    love.graphics.setColor(self.colors.panelBg)
    love.graphics.rectangle('fill', x, y, w, h, 10, 10)
    love.graphics.setColor(self.colors.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', x, y, w, h, 10, 10)
    love.graphics.setLineWidth(1)

    -- Stars
    local sx = x + 12
    local sy = y + 16
    local r = 6
    for i=1,self.starsTarget do
        if i <= self.stars then love.graphics.setColor(self.colors.starFilled) else love.graphics.setColor(self.colors.starEmpty) end
        drawStar(sx + (i-1)* (r*2 + 6), sy, r)
    end

    -- Template drawing area
    local pad = 16
    local tx = x + pad
    local ty = y + 40
    local tw = w - pad*2
    local th = h - 90

    -- Determine stroke color with flash lerp
    local t = self.flashT / 0.3
    t = math.max(0, math.min(1, t))
    local c1, c2 = self.colors.stroke, self.colors.success
    local rL = c1[1] + (c2[1]-c1[1]) * t
    local gL = c1[2] + (c2[2]-c1[2]) * t
    local bL = c1[3] + (c2[3]-c1[3]) * t
    local aL = c1[4] + (c2[4]-c1[4]) * t
    love.graphics.setColor(rL, gL, bL, aL)
    love.graphics.setLineWidth(3)

    -- Render normalized template inside panel (0..1 coords supported)
    local pts = self.template.points or {}
    if #pts >= 2 then
        -- Compute bounds if not normalized
        local minx, miny, maxx, maxy = 1e9, 1e9, -1e9, -1e9
        for _,p in ipairs(pts) do
            local px = p.x or p.i or 0
            local py = p.y or p.j or 0
            minx = math.min(minx, px); maxx = math.max(maxx, px)
            miny = math.min(miny, py); maxy = math.max(maxy, py)
        end
        local w0 = maxx - minx; local h0 = maxy - miny
        local norm = (maxx<=1 and maxy<=1)
        if w0 == 0 then w0 = 1 end; if h0 == 0 then h0 = 1 end
        -- scale to fit tw x th preserving aspect
        local sx = tw / (norm and 1 or w0)
        local sy = th / (norm and 1 or h0)
        local s = math.min(sx, sy)
        -- center
        local ox = tx + (tw - (norm and tw or (w0*s))) / 2
        local oy = ty + (th - (norm and th or (h0*s))) / 2
        local function map(p)
            local px = p.x or p.i or 0
            local py = p.y or p.j or 0
            if not norm then px = px - minx; py = py - miny end
            return ox + px * s, oy + py * s
        end
        for i=1,#pts-1 do
            local x1,y1 = map(pts[i])
            local x2,y2 = map(pts[i+1])
            love.graphics.line(x1,y1,x2,y2)
        end
        if self.template.closed and #pts>2 then
            local x1,y1 = map(pts[#pts])
            local x2,y2 = map(pts[1])
            love.graphics.line(x1,y1,x2,y2)
        end
    end
    love.graphics.setLineWidth(1)

    -- Text + data block
    love.graphics.setFont(self.font)
    love.graphics.setColor(self.colors.text)
    local levelText = string.format("LEVEL %d", (self.stats and self.stats.level) or (_G and _G.currentLevel) or 1)
    local targetText = string.format("Target: %s", self.template.name or (self.stats and self.stats.target) or "?")
    local reqText = string.format("Required: %d%%", math.floor(self.template.required or (self.stats and self.stats.requiredAcc) or 80))
    love.graphics.print(levelText, x+12, y + h - 44)
    love.graphics.print(targetText, x+12, y + h - 28)
    love.graphics.print(reqText, x+12, y + h - 12)

    -- Separator
    love.graphics.setColor(1,1,1,0.08)
    love.graphics.rectangle('fill', x+10, y + h + 6, w-20, 1, 0, 0)
    love.graphics.setColor(self.colors.text)

    -- Data block under card (draw to the right pane, not inside card bounds)
    local dx = x
    local dy = y + h + 12
    local lineH = 18
    local function row(label, value)
        love.graphics.print(label, dx+12, dy)
        local txt = tostring(value or '')
        local tw = self.font:getWidth(txt)
        love.graphics.print(txt, dx + w - 12 - tw, dy)
        dy = dy + lineH
    end
    if self.stats then
        row('Required:', string.format('%d%%', self.stats.requiredAcc or 0))
        row('Claimed:', string.format('%d%% / %d%%', self.stats.claimed or 0, self.stats.requiredClaimed or 0))
        row('Shape:', string.format('%d%%', self.stats.shapeAcc or 0))
        row('Lives:', self.stats.lives or 0)
        row('Enemies:', self.stats.enemies or 0)
        row('Time:', self.stats.time or 0)
        row('Score:', self.stats.score or 0)
        row('Combo:', string.format('x%.1f', self.stats.combo or 1.0))
    end
end

return ShapePanel
