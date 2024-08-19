local lib = require "library"
local json = require "json"

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
local cursor = 0  --- @type integer
local currentVideo = nil  --- @type table?
local currentSearch = nil  --- @type table?
local currentError = nil  --- @type string?
local currentInfo = nil  --- @type string?

--- Timey wimey stuff
local time = {}
time.framerate = 60
time.perSecond = (1 / time.framerate)
time.delta = time.perSecond

--- The Invidious YouTube API
local api = {}
api.base = "https://inv.nadeko.net/api/v1/"   -- TODO: Allow several API backends, use backup instances in case a request to one of them fails
api.search_video = function (searchString)
    local url = api.base .. "search?q=" .. textutils.urlEncode(searchString)
    local req = http.get({ url = url, binary = false })
    local data = json.parse(req.readAll())
    req.close()
    if data ~= nil and type(data) == "table" then 
        currentSearch = data
    else
        currentError = "Received search result data is invalid.\nNot a table, or nil"
    end
end
api.fetch_video = function (hash)
    local url = api.base .. "videos/" .. hash
    http.request({ url = url, binary = false })
    debug.requested_url = url
end

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
ui.unloadTheme = function ()
    for name, color in pairs(colors) do
        if type(color) == "number" and lib.color[name] ~= nil then
            for _, monitor in pairs(monitors) do
                monitor.setPaletteColor(color, lib.color[name])
            end
        end
    end
end
ui.loadBuiltinTheme = function (theme)
    ui.unloadTheme()
    if theme == ui.themes.generic then
        for _, monitor in pairs(monitors) do
            monitor.setPaletteColor(colors.cyan, lib.color.blend(lib.color.cyan, lib.color.black))
            monitor.setPaletteColor(colors.gray, lib.color.blend(lib.color.gray, lib.color.black))
            monitor.setPaletteColor(colors.pink, lib.color.blend(lib.color.black, lib.color.brown, 0.3))
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
            monitor.setPaletteColor(colors.white, lib.color.blend(lib.color.white, lib.color.brown))
            monitor.setPaletteColor(colors.red, lib.color.blend(lib.color.red, lib.color.brown))
            monitor.setPaletteColor(colors.gray, lib.color.blend(lib.color.gray, lib.color.brown))
            monitor.setPaletteColor(colors.black, lib.color.blend(lib.color.black, lib.color.brown))
            monitor.setPaletteColor(colors.pink, lib.color.blend(lib.color.black, lib.color.brown, 0.3))
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

local debug = {}

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
    draw = function(monitor)
        local width, height = monitor.getSize()

        -- Always visible
        local tabs = {
            { ui.pages.home, "Home" },
            { ui.pages.search, "Search" },
            { ui.pages.watch, "Watch" },
            { ui.pages.settings, "Settings" }
        }
        for i, tab in pairs(tabs) do
            monitor.setBackgroundColor(page == tab[1] and ui.colors.back.primary or ui.colors.back.secondary)
            monitor.write(tab[2])
            monitor.setBackgroundColor(ui.colors.back.clear)
            monitor.write(" ")
        end

        -- Page-specific
        if ui.page == ui.pages.search then
            -- TODO: Render search
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
        sleep(time.perSecond)
    end
    local function drawHandler()
        for i, monitor in pairs(monitors) do
            monitor.setBackgroundColor(ui.colors.back.clear)
            monitor.setTextColor(ui.colors.front.text)
            monitor.clear()
            monitor.setCursorPos(2,2)
            MediaApp.draw(monitor)
        end
        sleep(time.perSecond)
    end

    -- state.running and calculating delta time
    local deltaStart = os.time()
    parallel.waitForAny(eventHandler, updateHandler)
    drawHandler()
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
