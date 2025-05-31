local EchoLab = {}

EchoLab.name = "Echo Lab"
EchoLab.description = "Zones close, re-open briefly, then reclose (echo effect)."

function EchoLab:load()
end

function EchoLab:update(dt)
    if self._echoLabTimer then
        self._echoLabTimer = self._echoLabTimer - dt
        if self._echoLabTimer <= 0 then
            for _, cell in ipairs(self._echoLabToClaim) do
                self.cells[cell.i][cell.j] = 'claimed'
            end
            self._echoLabTimer = nil
            self._echoLabToClaim = nil
        end
    end
end

function EchoLab:draw()
end

function EchoLab:onZoneClosed(grid)
    -- אפקט ויזואלי בלבד: לא לשנות claimed בפועל, רק להוסיף דגל ויזואלי
    -- אפשר לסמן grid._echoLabVisual = true ולצייר אפקט זמני ב-draw
    -- לא לשנות grid.cells[i][j] ל-'empty' בפועל, כדי לא לשבור את הלוגיקה של סגירת שטח
    grid._echoLabVisual = 0.5 -- זמן לאפקט
end

return EchoLab
