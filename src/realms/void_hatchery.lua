local VoidHatchery = {}

VoidHatchery.name = "Void Hatchery"
VoidHatchery.description = "Classic: closed zones are permanent. (Splitting effect reserved for boss only)"

function VoidHatchery:onZoneClosed(grid)
    -- No effect: classic behavior, do not remove claimed cells
end

return VoidHatchery
