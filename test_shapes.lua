-- Test script for 50-level shape system
local ShapeTemplates = require 'src.systems.shape_templates'

print("Testing 50-Level Shape Progression System")
print("========================================")

-- Test first 10 levels
for level = 1, 10 do
    local shape = ShapeTemplates:getShapeForLevel(level)
    if shape then
        print("Level " .. level .. ": " .. (shape.name or "Unknown") .. " (" .. (shape.requiredAccuracy or 80) .. "% accuracy, Difficulty " .. (shape.difficulty or 1) .. ")")
    else
        print("Level " .. level .. ": ERROR - No shape found!")
    end
end

print()
print("Testing key milestone levels:")

-- Test milestone levels
local milestones = {15, 25, 35, 45, 50}
for _, level in ipairs(milestones) do
    local shape = ShapeTemplates:getShapeForLevel(level)
    if shape then
        print("Level " .. level .. ": " .. (shape.name or "Unknown") .. " (" .. (shape.requiredAccuracy or 80) .. "% accuracy, Difficulty " .. (shape.difficulty or 1) .. ")")
    else
        print("Level " .. level .. ": ERROR - No shape found!")
    end
end

print()
print("✅ Shape system test complete!")
