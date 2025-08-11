-- src/systems/shape_templates.lua
-- Comprehensive 50-Level Shape Progression System

local ShapeTemplates = {}

-- ✅ MASTER 50-LEVEL SHAPE PROGRESSION LIST
local SHAPE_PROGRESSION = {
    -- Level 1-5: Basic Shapes
    {level = 1, type = "triangle", name = "Triangle", difficulty = 1, requiredAccuracy = 70},
    {level = 2, type = "square", name = "Square", difficulty = 1, requiredAccuracy = 70},
    {level = 3, type = "circle", name = "Circle", difficulty = 2, requiredAccuracy = 75},
    {level = 4, type = "horizontal_line", name = "Horizontal Line", difficulty = 1, requiredAccuracy = 65},
    {level = 5, type = "vertical_line", name = "Vertical Line", difficulty = 1, requiredAccuracy = 65},
    
    -- Level 6-10: Simple Composite Shapes
    {level = 6, type = "l_shape", name = "L-Shape", difficulty = 2, requiredAccuracy = 75},
    {level = 7, type = "t_shape", name = "T-Shape", difficulty = 2, requiredAccuracy = 75},
    {level = 8, type = "plus", name = "Plus Sign", difficulty = 2, requiredAccuracy = 75},
    {level = 9, type = "rectangle", name = "Rectangle", difficulty = 2, requiredAccuracy = 75},
    {level = 10, type = "diagonal", name = "Diagonal Line", difficulty = 2, requiredAccuracy = 70},
    
    -- Level 11-15: Size Variations
    {level = 11, type = "large_triangle", name = "Large Triangle", difficulty = 2, requiredAccuracy = 75},
    {level = 12, type = "large_square", name = "Large Square", difficulty = 2, requiredAccuracy = 75},
    {level = 13, type = "small_circle", name = "Small Circle", difficulty = 2, requiredAccuracy = 80},
    {level = 14, type = "large_circle", name = "Large Circle", difficulty = 3, requiredAccuracy = 80},
    {level = 15, type = "diamond", name = "Diamond", difficulty = 3, requiredAccuracy = 80},
    
    -- Level 16-20: Angular Shapes
    {level = 16, type = "trapezoid", name = "Trapezoid", difficulty = 3, requiredAccuracy = 80},
    {level = 17, type = "chevron", name = "Chevron", difficulty = 3, requiredAccuracy = 80},
    {level = 18, type = "lightning", name = "Lightning Bolt", difficulty = 4, requiredAccuracy = 85},
    {level = 19, type = "hollow_square", name = "Hollow Square", difficulty = 3, requiredAccuracy = 80},
    {level = 20, type = "star", name = "Star", difficulty = 4, requiredAccuracy = 85},
    
    -- Level 21-25: Curved & Complex
    {level = 21, type = "spiral", name = "Spiral", difficulty = 4, requiredAccuracy = 85},
    {level = 22, type = "zigzag", name = "Zigzag", difficulty = 3, requiredAccuracy = 80},
    {level = 23, type = "cross", name = "Cross", difficulty = 3, requiredAccuracy = 80},
    {level = 24, type = "heart", name = "Heart", difficulty = 5, requiredAccuracy = 85},
    {level = 25, type = "infinity", name = "Infinity Symbol", difficulty = 5, requiredAccuracy = 85},
    
    -- Level 26-30: Advanced Symbols
    {level = 26, type = "yin_yang", name = "Yin-Yang", difficulty = 6, requiredAccuracy = 85},
    {level = 27, type = "hourglass", name = "Hourglass", difficulty = 4, requiredAccuracy = 85},
    {level = 28, type = "pentagon", name = "Pentagon", difficulty = 4, requiredAccuracy = 85},
    {level = 29, type = "hexagon", name = "Hexagon", difficulty = 4, requiredAccuracy = 85},
    {level = 30, type = "octagon", name = "Octagon", difficulty = 5, requiredAccuracy = 85},
    
    -- Level 31-35: Objects & Symbols
    {level = 31, type = "umbrella", name = "Umbrella", difficulty = 5, requiredAccuracy = 85},
    {level = 32, type = "mushroom", name = "Mushroom", difficulty = 5, requiredAccuracy = 85},
    {level = 33, type = "keyhole", name = "Keyhole", difficulty = 5, requiredAccuracy = 85},
    {level = 34, type = "question_mark", name = "Question Mark", difficulty = 5, requiredAccuracy = 85},
    {level = 35, type = "exclamation", name = "Exclamation Mark", difficulty = 4, requiredAccuracy = 85},
    
    -- Level 36-40: Complex Objects
    {level = 36, type = "house", name = "House", difficulty = 5, requiredAccuracy = 85},
    {level = 37, type = "tree", name = "Tree", difficulty = 6, requiredAccuracy = 85},
    {level = 38, type = "fish", name = "Fish", difficulty = 6, requiredAccuracy = 85},
    {level = 39, type = "ghost", name = "Ghost", difficulty = 5, requiredAccuracy = 85},
    {level = 40, type = "duck", name = "Duck", difficulty = 6, requiredAccuracy = 85},
    
    -- Level 41-45: Compound Shapes
    {level = 41, type = "glasses", name = "Glasses", difficulty = 6, requiredAccuracy = 85},
    {level = 42, type = "cloud_lightning", name = "Lightning Cloud", difficulty = 7, requiredAccuracy = 90},
    {level = 43, type = "musical_note", name = "Musical Note", difficulty = 6, requiredAccuracy = 85},
    {level = 44, type = "moon_star", name = "Moon & Star", difficulty = 7, requiredAccuracy = 90},
    {level = 45, type = "flag", name = "Flag", difficulty = 6, requiredAccuracy = 85},
    
    -- Level 46-50: Master Level Shapes
    {level = 46, type = "rain_cloud", name = "Rain Cloud", difficulty = 7, requiredAccuracy = 90},
    {level = 47, type = "crown", name = "Crown", difficulty = 7, requiredAccuracy = 90},
    {level = 48, type = "smile", name = "Smiley Face", difficulty = 6, requiredAccuracy = 85},
    {level = 49, type = "olympic_rings", name = "Olympic Rings", difficulty = 8, requiredAccuracy = 90},
    {level = 50, type = "voidline_logo", name = "Voidline Logo", difficulty = 9, requiredAccuracy = 95}
}

-- ✅ GET SHAPE FOR SPECIFIC LEVEL
-- Helper functions (defined before templates)
function ShapeTemplates.generateCircle(centerX, centerY, radius, segments)
    local points = {}
    for i = 0, segments - 1 do
        local angle = (i / segments) * 2 * math.pi
        local x = centerX + math.cos(angle) * radius
        local y = centerY + math.sin(angle) * radius
        table.insert(points, {x = x, y = y})
    end
    return points
end

function ShapeTemplates.generateStar(centerX, centerY, outerRadius, innerRadius, points)
    local coords = {}
    for i = 0, points * 2 - 1 do
        local angle = (i / (points * 2)) * 2 * math.pi
        local radius = (i % 2 == 0) and outerRadius or innerRadius
        local x = centerX + math.cos(angle) * radius
        local y = centerY + math.sin(angle) * radius
        table.insert(coords, {x = x, y = y})
    end
    return coords
end

function ShapeTemplates.generateSpiral(centerX, centerY, startRadius, endRadius, turns)
    local points = {}
    local segments = math.floor(turns * 12) -- 12 points per turn
    
    for i = 0, segments do
        local t = i / segments
        local angle = t * turns * 2 * math.pi
        local radius = startRadius + t * (endRadius - startRadius)
        local x = centerX + math.cos(angle) * radius
        local y = centerY + math.sin(angle) * radius
        table.insert(points, {x = x, y = y})
    end
    return points
end

-- ✅ GENERATE BASIC SHAPES FOR MISSING TEMPLATES
function ShapeTemplates:generateBasicShape(shapeInfo)
    local template = {
        type = shapeInfo.type,
        name = shapeInfo.name,
        difficulty = shapeInfo.difficulty,
        requiredAccuracy = shapeInfo.requiredAccuracy,
        level = shapeInfo.level,
        points = {}
    }
    
    -- Generate basic shape coordinates based on type
    if shapeInfo.type == "triangle" or shapeInfo.type == "large_triangle" then
        template.points = {{x=0.5,y=0.1}, {x=0.1,y=0.9}, {x=0.9,y=0.9}, {x=0.5,y=0.1}}
    elseif shapeInfo.type == "square" or shapeInfo.type == "large_square" then
        template.points = {{x=0.2,y=0.2}, {x=0.8,y=0.2}, {x=0.8,y=0.8}, {x=0.2,y=0.8}, {x=0.2,y=0.2}}
    elseif shapeInfo.type == "circle" or shapeInfo.type == "small_circle" or shapeInfo.type == "large_circle" then
        template.points = self.generateCircle(0.5, 0.5, 0.3, 16)
    elseif shapeInfo.type == "horizontal_line" then
        template.points = {{x=0.1,y=0.5}, {x=0.9,y=0.5}}
    elseif shapeInfo.type == "vertical_line" then
        template.points = {{x=0.5,y=0.1}, {x=0.5,y=0.9}}
    elseif shapeInfo.type == "rectangle" then
        template.points = {{x=0.1,y=0.3}, {x=0.9,y=0.3}, {x=0.9,y=0.7}, {x=0.1,y=0.7}, {x=0.1,y=0.3}}
    elseif shapeInfo.type == "diamond" then
        template.points = {{x=0.5,y=0.1}, {x=0.9,y=0.5}, {x=0.5,y=0.9}, {x=0.1,y=0.5}, {x=0.5,y=0.1}}
    elseif shapeInfo.type == "star" then
        template.points = self.generateStar(0.5, 0.5, 0.4, 0.2, 5)
    elseif shapeInfo.type == "heart" then
        template.points = {{x=0.5,y=0.3}, {x=0.3,y=0.1}, {x=0.1,y=0.3}, {x=0.1,y=0.5}, {x=0.5,y=0.9}, {x=0.9,y=0.5}, {x=0.9,y=0.3}, {x=0.7,y=0.1}, {x=0.5,y=0.3}}
    else
        -- Default to square for unknown shapes
        template.points = {{x=0.2,y=0.2}, {x=0.8,y=0.2}, {x=0.8,y=0.8}, {x=0.2,y=0.8}, {x=0.2,y=0.2}}
    end
    
    return template
end
function ShapeTemplates.generateCircle(centerX, centerY, radius, segments)
    local points = {}
    for i = 0, segments - 1 do
        local angle = (i / segments) * 2 * math.pi
        local x = centerX + math.cos(angle) * radius
        local y = centerY + math.sin(angle) * radius
        table.insert(points, {x = x, y = y})
    end
    return points
end

function ShapeTemplates.generateStar(centerX, centerY, outerRadius, innerRadius, points)
    local coords = {}
    for i = 0, points * 2 - 1 do
        local angle = (i / (points * 2)) * 2 * math.pi
        local radius = (i % 2 == 0) and outerRadius or innerRadius
        local x = centerX + math.cos(angle) * radius
        local y = centerY + math.sin(angle) * radius
        table.insert(coords, {x = x, y = y})
    end
    return coords
end

function ShapeTemplates.generateSpiral(centerX, centerY, startRadius, endRadius, turns)
    local points = {}
    local segments = math.floor(turns * 12) -- 12 points per turn
    
    for i = 0, segments do
        local t = i / segments
        local angle = t * turns * 2 * math.pi
        local radius = startRadius + t * (endRadius - startRadius)
        local x = centerX + math.cos(angle) * radius
        local y = centerY + math.sin(angle) * radius
        table.insert(points, {x = x, y = y})
    end
    return points
end

-- Shape template structure:
-- {
--   name = "Triangle",
--   description = "Draw a triangle shape",
--   difficulty = 1, -- 1-5 scale
--   points = { {x, y}, {x, y}, ... }, -- Normalized coordinates (0-1)
--   closed = true, -- Whether the shape should be closed
--   tolerance = 0.15 -- Matching tolerance (lower = more precise)
-- }

ShapeTemplates.templates = {
    -- LEVEL 1 - Very Simple Shapes (Tutorial)
    {
        name = "Triangle",
        description = "Draw a simple triangle",
        difficulty = 1,
        type = "triangle", -- Add type for better shape matching
        points = {
            {x = 0.5, y = 0.2},  -- Top
            {x = 0.2, y = 0.8},  -- Bottom left
            {x = 0.8, y = 0.8},  -- Bottom right
            {x = 0.5, y = 0.2}   -- Back to top (closed)
        },
        closed = true,
        tolerance = 0.25
    },
    
    {
        name = "Square",
        description = "Draw a simple square",
        difficulty = 1,
        type = "square",
        points = {
            {x = 0.3, y = 0.3},  -- Top left
            {x = 0.7, y = 0.3},  -- Top right
            {x = 0.7, y = 0.7},  -- Bottom right
            {x = 0.3, y = 0.7},  -- Bottom left
            {x = 0.3, y = 0.3}   -- Back to start (closed)
        },
        closed = true,
        tolerance = 0.25
    },

    {
        name = "Rectangle",
        description = "Draw a simple rectangle",
        difficulty = 1,
        type = "rectangle",
        points = {
            {x = 0.2, y = 0.35}, -- Top left
            {x = 0.8, y = 0.35}, -- Top right
            {x = 0.8, y = 0.65}, -- Bottom right
            {x = 0.2, y = 0.65}, -- Bottom left
            {x = 0.2, y = 0.35}  -- Back to start
        },
        closed = true,
        tolerance = 0.25
    },
    
    -- LEVEL 2 - Basic Geometric Shapes
    {
        name = "Circle",
        description = "Draw a circular path",
        difficulty = 2,
        type = "circle",
        points = {
            {x = 0.8, y = 0.5},   -- Right
            {x = 0.65, y = 0.25}, -- Top-right
            {x = 0.5, y = 0.2},   -- Top
            {x = 0.35, y = 0.25}, -- Top-left
            {x = 0.2, y = 0.5},   -- Left
            {x = 0.35, y = 0.75}, -- Bottom-left
            {x = 0.5, y = 0.8},   -- Bottom
            {x = 0.65, y = 0.75}, -- Bottom-right
            {x = 0.8, y = 0.5}    -- Back to start
        },
        closed = true,
        tolerance = 0.25
    },

    {
        name = "Diamond",
        description = "Draw a diamond shape",
        difficulty = 2,
        type = "diamond",
        points = {
            {x = 0.5, y = 0.2},  -- Top
            {x = 0.8, y = 0.5},  -- Right
            {x = 0.5, y = 0.8},  -- Bottom
            {x = 0.2, y = 0.5},  -- Left
            {x = 0.5, y = 0.2}   -- Back to top
        },
        closed = true,
        tolerance = 0.22
    },

    {
        name = "Pentagon",
        description = "Draw a pentagon (5 sides)",
        difficulty = 2,
        type = "pentagon",
        points = {
            {x = 0.5, y = 0.2},   -- Top
            {x = 0.8, y = 0.4},   -- Top-right
            {x = 0.7, y = 0.8},   -- Bottom-right
            {x = 0.3, y = 0.8},   -- Bottom-left
            {x = 0.2, y = 0.4},   -- Top-left
            {x = 0.5, y = 0.2}    -- Back to top
        },
        closed = true,
        tolerance = 0.20
    },
    
    -- LEVEL 3 - Moderate Complexity (Symbols)
    {
        name = "Plus Sign",
        description = "Draw a plus sign (+)",
        difficulty = 3,
        type = "plus",
        points = {
            {x = 0.5, y = 0.2},  -- Top center
            {x = 0.5, y = 0.4},  -- Down to horizontal
            {x = 0.8, y = 0.4},  -- Right
            {x = 0.8, y = 0.6},  -- Down
            {x = 0.5, y = 0.6},  -- Back to center
            {x = 0.5, y = 0.8},  -- Down
            {x = 0.4, y = 0.8},  -- Left
            {x = 0.4, y = 0.6},  -- Up
            {x = 0.2, y = 0.6},  -- Left
            {x = 0.2, y = 0.4},  -- Up
            {x = 0.4, y = 0.4},  -- Right to center
            {x = 0.4, y = 0.2},  -- Up
            {x = 0.5, y = 0.2}   -- Close
        },
        closed = true,
        tolerance = 0.18
    },

    {
        name = "Heart",
        description = "Draw a heart shape",
        difficulty = 3,
        type = "heart",
        points = {
            {x = 0.5, y = 0.6},   -- Bottom point
            {x = 0.3, y = 0.4},   -- Left curve bottom
            {x = 0.2, y = 0.3},   -- Left curve top
            {x = 0.35, y = 0.2},  -- Left heart top
            {x = 0.5, y = 0.35},  -- Center dip
            {x = 0.65, y = 0.2},  -- Right heart top
            {x = 0.8, y = 0.3},   -- Right curve top
            {x = 0.7, y = 0.4},   -- Right curve bottom
            {x = 0.5, y = 0.6}    -- Back to bottom
        },
        closed = true,
        tolerance = 0.18
    },

    {
        name = "Hexagon",
        description = "Draw a hexagon (6 sides)",
        difficulty = 3,
        type = "hexagon",
        points = {
            {x = 0.5, y = 0.2},   -- Top
            {x = 0.75, y = 0.35}, -- Top-right
            {x = 0.75, y = 0.65}, -- Bottom-right
            {x = 0.5, y = 0.8},   -- Bottom
            {x = 0.25, y = 0.65}, -- Bottom-left
            {x = 0.25, y = 0.35}, -- Top-left
            {x = 0.5, y = 0.2}    -- Back to top
        },
        closed = true,
        tolerance = 0.18
    },
    
    -- LEVEL 4 - Complex Shapes
    {
        name = "Star",
        description = "Draw a 5-pointed star",
        difficulty = 4,
        type = "star",
        points = {
            {x = 0.5, y = 0.15},  -- Top point
            {x = 0.6, y = 0.4},   -- Inner top-right
            {x = 0.85, y = 0.4},  -- Outer right
            {x = 0.65, y = 0.6},  -- Inner bottom-right
            {x = 0.75, y = 0.85}, -- Bottom-right point
            {x = 0.5, y = 0.7},   -- Inner bottom
            {x = 0.25, y = 0.85}, -- Bottom-left point
            {x = 0.35, y = 0.6},  -- Inner bottom-left
            {x = 0.15, y = 0.4},  -- Outer left
            {x = 0.4, y = 0.4},   -- Inner top-left
            {x = 0.5, y = 0.15}   -- Back to top
        },
        closed = true,
        tolerance = 0.15
    },

    {
        name = "Butterfly",
        description = "Draw a butterfly outline",
        difficulty = 4,
        type = "butterfly",
        points = {
            {x = 0.5, y = 0.2},   -- Top center (head)
            {x = 0.3, y = 0.1},   -- Left antenna
            {x = 0.5, y = 0.2},   -- Back to head
            {x = 0.7, y = 0.1},   -- Right antenna
            {x = 0.5, y = 0.2},   -- Back to head
            {x = 0.2, y = 0.4},   -- Left upper wing
            {x = 0.1, y = 0.5},   -- Left wing tip
            {x = 0.3, y = 0.7},   -- Left lower wing
            {x = 0.5, y = 0.8},   -- Bottom center
            {x = 0.7, y = 0.7},   -- Right lower wing
            {x = 0.9, y = 0.5},   -- Right wing tip
            {x = 0.8, y = 0.4},   -- Right upper wing
            {x = 0.5, y = 0.2}    -- Back to head
        },
        closed = true,
        tolerance = 0.15
    },

    {
        name = "House",
        description = "Draw a simple house",
        difficulty = 4,
        type = "house",
        points = {
            {x = 0.2, y = 0.6},   -- Bottom left
            {x = 0.2, y = 0.4},   -- Wall left
            {x = 0.5, y = 0.2},   -- Roof peak
            {x = 0.8, y = 0.4},   -- Wall right top
            {x = 0.8, y = 0.6},   -- Wall right
            {x = 0.65, y = 0.6},  -- Door top right
            {x = 0.65, y = 0.8},  -- Door bottom right
            {x = 0.35, y = 0.8},  -- Door bottom left
            {x = 0.35, y = 0.6},  -- Door top left
            {x = 0.2, y = 0.6}    -- Back to start
        },
        closed = true,
        tolerance = 0.15
    },
    
    -- LEVEL 5 - Very Complex Shapes
    {
        name = "Fish",
        description = "Draw a fish silhouette",
        difficulty = 5,
        type = "fish",
        points = {
            {x = 0.2, y = 0.5},   -- Nose
            {x = 0.4, y = 0.3},   -- Top of head
            {x = 0.6, y = 0.2},   -- Back top
            {x = 0.8, y = 0.3},   -- Tail start top
            {x = 0.9, y = 0.1},   -- Tail top
            {x = 0.85, y = 0.5},  -- Tail center
            {x = 0.9, y = 0.9},   -- Tail bottom
            {x = 0.8, y = 0.7},   -- Tail start bottom
            {x = 0.6, y = 0.8},   -- Back bottom
            {x = 0.4, y = 0.7},   -- Bottom of head
            {x = 0.2, y = 0.5}    -- Back to nose
        },
        closed = true,
        tolerance = 0.12
    },

    {
        name = "Lightning",
        description = "Draw a lightning bolt",
        difficulty = 5,
        type = "lightning",
        points = {
            {x = 0.4, y = 0.1},   -- Top left
            {x = 0.6, y = 0.1},   -- Top right
            {x = 0.5, y = 0.4},   -- Middle bend
            {x = 0.7, y = 0.4},   -- Right extension
            {x = 0.3, y = 0.9},   -- Bottom point
            {x = 0.45, y = 0.6},  -- Left indent
            {x = 0.4, y = 0.1}    -- Back to top
        },
        closed = false, -- Lightning is an open path
        tolerance = 0.12
    },

    {
        name = "Flower",
        description = "Draw a simple flower",
        difficulty = 5,
        type = "flower",
        points = {
            {x = 0.5, y = 0.4},   -- Center
            {x = 0.5, y = 0.2},   -- Top petal
            {x = 0.5, y = 0.4},   -- Back to center
            {x = 0.7, y = 0.3},   -- Top-right petal
            {x = 0.5, y = 0.4},   -- Back to center
            {x = 0.8, y = 0.5},   -- Right petal
            {x = 0.5, y = 0.4},   -- Back to center
            {x = 0.7, y = 0.7},   -- Bottom-right petal
            {x = 0.5, y = 0.4},   -- Back to center
            {x = 0.5, y = 0.8},   -- Bottom petal
            {x = 0.5, y = 0.4},   -- Back to center
            {x = 0.3, y = 0.7},   -- Bottom-left petal
            {x = 0.5, y = 0.4},   -- Back to center
            {x = 0.2, y = 0.5},   -- Left petal
            {x = 0.5, y = 0.4},   -- Back to center
            {x = 0.3, y = 0.3},   -- Top-left petal
            {x = 0.5, y = 0.4}    -- Back to center
        },
        closed = true,
        tolerance = 0.10
    }
}

-- ✅ COMPREHENSIVE LEVEL-BASED SHAPE SELECTION (REPLACES OLD SYSTEM)
function ShapeTemplates:getShapeForLevel(level)
    -- Find the exact shape for this level from progression list
    local shapeInfo = nil
    for _, shape in ipairs(SHAPE_PROGRESSION) do
        if shape.level == level then
            shapeInfo = shape
            break
        end
    end
    
    if not shapeInfo then
        -- Fallback for levels beyond 50 - cycle through advanced shapes
        local fallbackLevel = ((level - 1) % 10) + 41  -- Use levels 41-50 as fallback
        for _, shape in ipairs(SHAPE_PROGRESSION) do
            if shape.level == fallbackLevel then
                shapeInfo = shape
                break
            end
        end
    end
    
    if not shapeInfo then
        -- Ultimate fallback
        shapeInfo = SHAPE_PROGRESSION[1]  -- Triangle
    end
    
    -- Get existing template or generate basic one
    local template = nil
    for _, t in ipairs(self.templates) do
        if t.type == shapeInfo.type then
            template = t
            break
        end
    end
    
    if not template then
        -- Generate basic shape if template doesn't exist
        template = self:generateBasicShape(shapeInfo)
    else
        -- Enhance existing template with level info
        template.level = level
        template.name = shapeInfo.name
        template.difficulty = shapeInfo.difficulty
        template.requiredAccuracy = shapeInfo.requiredAccuracy
        template.type = shapeInfo.type
    end
    
    return template
end

-- Get random shape of specific difficulty
function ShapeTemplates:getShapeByDifficulty(difficulty)
    local shapes = {}
    for _, template in ipairs(self.templates) do
        if template.difficulty == difficulty then
            table.insert(shapes, template)
        end
    end
    
    if #shapes > 0 then
        return shapes[math.random(1, #shapes)]
    else
        return self.templates[1] -- Fallback
    end
end

-- Get shape feedback for player guidance
function ShapeTemplates:getShapeFeedback(templateType, accuracy)
    local feedbacks = {
        triangle = {
            high = "Great triangle! Perfect angles!",
            medium = "Good triangle shape, try sharper corners",
            low = "Try drawing three connected sides"
        },
        square = {
            high = "Perfect square! Right angles achieved!",
            medium = "Good rectangle, make it more square",
            low = "Try drawing four equal sides"
        },
        circle = {
            high = "Excellent circle! Very smooth!",
            medium = "Good rounded shape, keep it smoother",
            low = "Try drawing in a smooth curved motion"
        },
        heart = {
            high = "Beautiful heart shape!",
            medium = "Nice heart, refine the curves",
            low = "Start at bottom point, curve up and around"
        },
        star = {
            high = "Amazing star! Perfect points!",
            medium = "Good star shape, sharpen those points",
            low = "Draw outward points, then inward dips"
        },
        default = {
            high = "Excellent shape matching!",
            medium = "Good attempt, keep practicing!",
            low = "Try to follow the target shape more closely"
        }
    }
    
    local shapeType = templateType or "default"
    local feedback = feedbacks[shapeType] or feedbacks.default
    
    if accuracy >= 80 then
        return feedback.high
    elseif accuracy >= 50 then
        return feedback.medium
    else
        return feedback.low
    end
end

-- Convert normalized coordinates to grid coordinates
function ShapeTemplates:convertToGridCoords(template, gridWidth, gridHeight, offsetX, offsetY)
    local gridTemplate = {
        name = template.name,
        description = template.description,
        difficulty = template.difficulty,
        closed = template.closed,
        tolerance = template.tolerance,
        type = template.type,
        points = {}
    }
    
    local drawableWidth = gridWidth * 0.6 -- Use 60% of grid for drawing space
    local drawableHeight = gridHeight * 0.6
    local startX = offsetX + (gridWidth - drawableWidth) / 2
    local startY = offsetY + (gridHeight - drawableHeight) / 2
    
    for _, point in ipairs(template.points) do
        table.insert(gridTemplate.points, {
            x = startX + point.x * drawableWidth,
            y = startY + point.y * drawableHeight
        })
    end
    
    return gridTemplate
end

return ShapeTemplates
