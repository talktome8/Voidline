-- requireAll.lua
-- Utility to require all Lua files in a directory
local lfs = love.filesystem or require('lfs')
local function requireAll(dir)
    local files = love.filesystem.getDirectoryItems(dir)
    for _, file in ipairs(files) do
        if file:match('%.lua$') then
            require(dir .. '/' .. file:gsub('%.lua$', ''))
        end
    end
end
return requireAll
