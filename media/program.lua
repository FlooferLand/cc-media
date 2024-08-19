local lib = require "library"
local api = lib.api
local hexColors = lib.color

-- Getting the peripherals
local monitors = { term, peripheral.find("monitor") }
local speakers = { peripheral.find("speaker") }
if #speakers < 1 then
    print("No speakers connected!")
end

-- State
local config = lib.config.make("media/conf.json")
local state = {
    running = true,
    searchString = ""
}
local cursor = {
    x = 0,  --- @type integer
    y = 0   --- @type integer
}
local currentVideo  = nil  --- @type table?
local currentSearch = nil  --- @type table?
local currentError  = nil  --- @type string?
local currentInfo   = nil  --- @type string?

--- Timey wimey stuff
local time = {}
time.framerate = 60
time.perSecond = (1 / time.framerate)
time.delta = time.perSecond

local ui = {
    colors = {
        front = {  -- Foreground
            text = colors.white,
            primary = colors.pink,
            secondary = colors.pink,
        },
        back = {  -- Background
            primary = colors.black,
            secondary = colors.black,
            clear = colors.black,
            clear2 = colors.black
        }
    },

    -- Constants
    themes = {
        generic = 0,
        steampunk = 1
    },
    pages = {
        home = 0,
        search = 1,
        watch = 2,
        settings = 3
    }
}
ui.page = ui.pages.search
ui.unloadTheme = function()
    for name, color in pairs(colors) do
        if type(color) == "number" and hexColors[name] ~= nil then
            for _, monitor in pairs(monitors) do
                monitor.setPaletteColor(color, hexColors[name])
            end
        end
    end
end
ui.loadBuiltinTheme = function(theme)
    ui.unloadTheme()
    if theme == ui.themes.generic then
        for _, monitor in pairs(monitors) do
            monitor.setPaletteColor(colors.cyan, hexColors.blend(hexColors.cyan, hexColors.black))
            monitor.setPaletteColor(colors.gray, hexColors.blend(hexColors.gray, hexColors.black))
            monitor.setPaletteColor(colors.pink, hexColors.blend(hexColors.black, hexColors.brown, 0.3))
        end
        ui.colors = {
            front = {
                text = colors.white,
                primary = colors.cyan,
                secondary = colors.lightGray,
            },
            back = {
                primary = colors.cyan,
                secondary = colors.gray,
                clear = colors.black,
                clear2 = colors.pink
            }
        }
    elseif theme == ui.themes.steampunk then
        for i, monitor in pairs(monitors) do
            monitor.setPaletteColor(colors.white, hexColors.blend(hexColors.white, hexColors.brown))
            monitor.setPaletteColor(colors.red, hexColors.blend(hexColors.red, hexColors.brown))
            monitor.setPaletteColor(colors.gray, hexColors.blend(hexColors.gray, hexColors.brown))
            monitor.setPaletteColor(colors.black, hexColors.blend(hexColors.black, hexColors.brown))
            monitor.setPaletteColor(colors.pink, hexColors.blend(hexColors.black, hexColors.brown, 0.3))
        end
        ui.colors = {
            front = {
                text = colors.white,
                primary = colors.red,
                secondary = colors.brown,
            },
            back = {
                primary = colors.brown,
                secondary = colors.gray,
                clear = colors.black,
                clear2 = colors.pink
            }
        }
    end
end

local tabs = {
    { ui.pages.home, "Home" },
    { ui.pages.search, "Search" },
    { ui.pages.watch, "Watch" },
    { ui.pages.settings, "Settings" }
}

local clicked = false  --- Whenever enter was pressed this frame

local debug = {}  --- Used for passing stuff between draw and update while testing


-- Main module
local MediaApp = {
    start = function()
        api.fetch_video("lHtBDOuyyJo")
    end,
    stop = function()
    end,
    
    --- @param key integer
    --- @param isHeld boolean
    input = function(key, isHeld)
        -- Cursor movement
        cursor.x = cursor.x - ((key == keys.left and cursor.x > 0) and 1 or 0)
        cursor.x = cursor.x + ((key == keys.right) and 1 or 0)
        cursor.y = cursor.y - ((key == keys.up and cursor.y > 0) and 1 or 0)
        cursor.y = cursor.y + ((key == keys.down) and 1 or 0)

        clicked = (key == keys.enter)

        -- Tabs
        if (key == keys.enter) and cursor.x > 0 and cursor.x < #tabs and cursor.y == 0 then
            ui.page = tabs[cursor.x][0]
        end

        -- Closing the error screen on any key
        if currentError ~= nil then
            currentError = nil
        end
    end,
    mouseInput = function() end,

    http = function(success, url, handleOrErr)
        if success then
            currentVideo = handleOrErr.readAll()
            ui.page = ui.pages.watch
            -- TODO: Play back the video
        else
            currentError = "Request to \""..url.."\" failed.\n"..handleOrErr
        end
    end,

    update = function()
    end,

    --- @param monitor any
    ui = function(monitor)
        local width, height = monitor.getSize()

        -- Always visible (top)
        if cursor.x > #tabs and cursor.y == 0 then
            cursor.y = 1
        end 
        for i, tab in pairs(tabs) do
            local active = (ui.page == tab[1])
            local selected = (cursor.x == i and cursor.y == 0)
            monitor.setBackgroundColor(active and ui.colors.back.primary or ui.colors.back.secondary)
            monitor.setTextColor(selected and (clicked and ui.colors.front.primary or ui.colors.front.secondary) or ui.colors.front.text)
            monitor.write((selected and "(" or "") .. tab[2] .. (selected and ")" or ""))
            monitor.setBackgroundColor(ui.colors.back.clear)
            monitor.setTextColor(ui.colors.front.text)
            monitor.write(" ")
        end

        -- Always visible (bottom)
        monitor.setCursorPos(1, height)
        monitor.write(("(".. cursor.x .. ", " .. cursor.y ..")") .. " | " .. (currentInfo ~= nil and currentInfo or "empty") .. " | " .. (math.random(0, 9)))

        -- Page-specific
        if ui.page == ui.pages.search then
            monitor.setBackgroundColor(ui.colors.back.secondary)
            local y = height * 0.12
            for x = width * 0.2, width * 0.8, 1 do
                monitor.setCursorPos(x, y)
                monitor.write("_")
            end
            monitor.setBackgroundColor(ui.colors.back.clear)
        end

        -- Always on top
        if currentError ~= nil then
            local x, y = width / 2, height / 2
            x = x - (currentError:len() / 2)
            monitor.setBackgroundColor(ui.colors.back.clear2)
            monitor.clear()
            monitor.setTextColor(colors.red)
            monitor.setCursorPos(x, y-2)
            monitor.write("Error!")

            monitor.setCursorPos(x, y)
            if currentError:len() > width then
                -- TODO: Fix the broken word wrapping system
                for i = 0, (currentError:len() / width), 1 do
                    monitor.setCursorPos(x, y + i)
                    local b = (currentError:len() / (width * i))
                    monitor.write(currentError:sub(b, currentError:len() > b+12 and b+12 or currentError:len()))
                end
            else
                monitor.write(currentError)
            end
            
            monitor.setCursorPos(x, y+2)
            monitor.setTextColor(colors.gray)
            monitor.write("Press any key to continue")
        end

        -- TODO: Use https://tweaked.cc/module/paintutils.html to draw videos
    end
}


-- Main loop
currentError = config:load()
MediaApp.start()
ui.loadBuiltinTheme(ui.themes.steampunk)
print("Starting..")
local stopProgram = function ()
    state.running = false
    MediaApp.stop()
    config:save()
    ui.unloadTheme()
end
while state.running do
    local function eventHandler()
        local event, data1, data2 = os.pullEventRaw()
        if event == "key" then
            local key, isHeld = data1, data2
            if event == "terminate" or key == keys.esc or key == keys.rightShift or key == keys.rightCtrl then
                stopProgram()
                return
            end
            MediaApp.input(key, isHeld)
        elseif event == "http_success" then
            local url, handle = data1, data2
            MediaApp.http(true, url, handle)
        elseif event == "http_failure" then
            local url, handle = data1, data2
            MediaApp.http(false, url, handle)
        end
    end
    local function updateHandler()
        if not state.running then
            return
        end
        MediaApp.update()
        sleep(0.0001)
    end
    local function uiHandler()
        for _, monitor in pairs(monitors) do
            monitor.setBackgroundColor(ui.colors.back.clear)
            monitor.setTextColor(ui.colors.front.text)
            monitor.clear()
            monitor.setCursorPos(2,2)
            MediaApp.ui(monitor)
        end
        sleep(0.0001)
    end

    -- running and calculating delta time
    local deltaStart = os.time()
    parallel.waitForAny(eventHandler, uiHandler) -- TODO: add updateHandler back
    sleep(time.perSecond)
    local deltaDiff = (os.time() - deltaStart)
    time.delta = deltaDiff >= 0 and deltaDiff or 0
end
for i, monitor in pairs(monitors) do
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    monitor.setCursorPos(1,1)
end
print("Exited the media program..")
