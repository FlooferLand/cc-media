local json = require "json"
--- Copy a table
local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Mafs
local extraMath = {
    lerp = function(a, b, t)
        return a + (b - a) * t
    end
}

-- Colour magic
local color = {
    white = 0xF0F0F0,
    orange = 0xF2B233,
    magenta = 0xE57FD8,
    lightBlue = 0x99B2F2,
    yellow = 0xDEDE6C,
    lime = 0x7FCC19,
    pink = 0xF2B2CC,
    gray = 0x4C4C4C,
    lightGray = 0x999999,
    cyan = 0x4C99B2,
    purple = 0xB266E5,
    blue = 0x3366CC,
    brown = 0x7F664C,
    green = 0x57A64E,
    red = 0xCC4C4C,
    black = 0x111111,

    ---@param color1 any
    ---@param color2 any
    ---@param t? number
    ---@return number
    blend = function (color1, color2, t)
        --if color1 == nil or color2 == nil then
        --    return color1 or color2 or nil
        --end
        if t == nil then
            t = 0.5
        end

        local one = {}
        local two = {}
        one.r, one.g, one.b = colors.unpackRGB(color1)
        two.r, two.g, two.b = colors.unpackRGB(color2)
        return colors.packRGB(
            extraMath.lerp(one.r, two.r, t),
            extraMath.lerp(one.g, two.g, t),
            extraMath.lerp(one.b, two.b, t)
        )
    end
}

-- Config stuff
local config = {
    --- @type string
    path = "",

    data = {
        monitors = {
            --- @type string[]
            browser = {},

            --- @type string[]
            displayer = {}
        },
        speakers = {
            --- @type string[]
            browser = {},

            --- @type string[]
            displayer = {}
        }
    }
};

--- Constructor
---@param path string
function config.make(path)
    local copy = deepcopy(config)
    copy.path = path
    return copy
end

--- Loads from a path
--- @return nil|string
function config.load(self)
    if not fs.exists(self.path) then
        local file = fs.open(self.path, "w")
        file.write(json.stringify(config.data))
        file.close()
    end

    local file = fs.open(self.path, "r")
    local config = json.parse(file.readAll()) or config.data
    file.close()
    if type(config) == "table" then
        self.data = config
        return nil
    else
        return "Error: Config file at path \""..self.path.."\" is not a JSON object!"
    end
end

--- Saves to a path
function config.save(self)
    local file = fs.open(self.path, "w")
    file.write(json.stringify(self.data))
    file.close()
end

-- Export
return {
    config = config,
    color = color,
    extraMath = extraMath,
    deepcopy = deepcopy,
    deserializeTable = deserializeTable,
    serializeTable = serializeTable
}
