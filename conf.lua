function love.conf(t)
    t.window.title = 'Voidline'
    t.window.width = 1450  -- Slightly wider for better layout and visibility
    t.window.height = 850  -- Taller to ensure close button is always visible
    t.window.vsync = 1
    t.window.resizable = true  -- Allow resizing so users can adjust
    t.window.fullscreen = false
    t.window.borderless = false  -- Keep window controls visible
    t.window.centered = true  -- Center the window on screen
    t.console = true -- Changed to true for debugging
end
