local lib = require "library"
local json = require "lib.json"
local hexColors = lib.color

-- Getting the peripherals
local monitors = { term.current(), peripheral.find("monitor") }
local speakers = { peripheral.find("speaker") }
if #speakers < 1 then
    print("No speakers connected!")
end

-- State
local config = lib.config.make("media/conf.json")
local state = {
    running = true,
    holdingCtrl = false,
    holdingShift = false,
    pleaseWait = false
}
local cursor = {
    x = 0,  --- @type integer
    y = 0   --- @type integer
}
local currentVideo  = nil  --- @type table? Invidious data regarding the current video
local currentSearch = nil  --- @type table? Invidious data regarding the current search
local currentError  = nil  --- @type string?
local currentInfo   = nil  --- @type string?

--- Timey wimey stuff
local time = {}
time.framerate = 60
time.perSecond = (1 / time.framerate)
time.delta = time.perSecond

local ui = {
    state = {
        searchBar = {
            string = "",
            selected = false,
            hovered = false
        }
    },
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
        generic = "generic",
        steampunk = "steampunk"
    },
    pages = {
        home = 0,     -- Main home page
        search = 1,   -- Search page
        video = 2,    -- Video page (title, description, etc)
        watch = 3,    -- Fullscreen video playback
        settings = 4  -- Settings
    }
}
ui.page = ui.pages.home
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
            monitor.setPaletteColor(colors.white, hexColors.white)
            monitor.setPaletteColor(colors.cyan, hexColors.blend(hexColors.cyan, hexColors.black, 0.2))
            monitor.setPaletteColor(colors.gray, hexColors.blend(hexColors.gray, hexColors.black, 0.2))
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
            monitor.setPaletteColor(colors.cyan, hexColors.blend(hexColors.red, hexColors.brown))
            
            monitor.setPaletteColor(colors.brown, hexColors.blend(hexColors.black, hexColors.brown, 0.6))
            monitor.setPaletteColor(colors.gray, hexColors.blend(hexColors.black, hexColors.brown, 0.3))
            monitor.setPaletteColor(colors.black, hexColors.blend(hexColors.black, hexColors.brown, 0.15))
            monitor.setPaletteColor(colors.pink, hexColors.blend(hexColors.black, hexColors.brown, 0.05))
        end
        ui.colors = {
            front = {
                text = colors.white,
                primary = colors.red,
                secondary = colors.cyan,
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
--- The Invidious YouTube API
local api = {}
api.url = {}
api.url.base = "https://inv.nadeko.net/api/v1/"   -- TODO: Allow several API backends, use backup instances in case a request to one of them fails
api.url.search = api.url.base .. "search"
api.url.watch = api.url.base .. "videos"
api.search_videos = function (searchString)
    local url = api.url.search .. "?q=" .. textutils.urlEncode(searchString)
    http.request({ url = url, binary = false })
    state.pleaseWait = true
end
api.fetch_video = function (hash)
    local url = api.url.watch .. "/" .. hash
    http.request({ url = url, binary = false })
end

local tabs = {
    { ui.pages.home, "Home" },
    { ui.pages.search, "Search" },
    { ui.pages.video, "Video" },
    { ui.pages.settings, "Settings" }
}

local clicked = false  --- Whenever enter was pressed this frame

local debug = {}  --- Used for passing stuff between draw and update while testing


-- Main module
local MediaApp = {
    start = function()
        -- api.fetch_video("lHtBDOuyyJo")
    end,
    stop = function()
    end,
    
    --- @param key integer
    --- @param isHeld boolean
    input = function(key, isHeld)
        -- Cursor and navigation
        cursor.x = cursor.x - ((key == keys.left and cursor.x > 0) and 1 or 0)
        cursor.x = cursor.x + ((key == keys.right) and 1 or 0)
        cursor.y = cursor.y - ((key == keys.up and cursor.y > 0) and 1 or 0)
        cursor.y = cursor.y + ((key == keys.down) and 1 or 0)
        clicked = (key == keys.enter)

        -- Tabs
        if clicked and cursor.x > 0 and cursor.x <= #tabs and cursor.y == 0 then
            ui.page = tabs[cursor.x][1]
        end

        -- Closing the error screen on any key
        if currentError ~= nil then
            currentError = nil
        end

        -- Specific input stuff
        if clicked and ui.state.searchBar.hovered then
            ui.state.searchBar.selected = true
        end
    end,
    mouseInput = function() end,

    ---@param success boolean
    ---@param url string
    ---@param handleOrErr any|string
    http = function(success, url, handleOrErr)
        if not success then
            currentError = "Request to \""..url.."\" failed.\n"..handleOrErr
            return
        end

        if url:match(api.url.search) ~= nil then
            state.pleaseWait = false
            local result = handleOrErr.readAll()
            if result ~= nil and #result > 0 then
                local data = json.parse(result)
                if data ~= nil and type(data) == "table" then
                    currentSearch = data
                else
                    currentError = "Received search result data couldn't be converted to JSON"
                end
            else
                currentError = "Received search result string data is invalid"
            end
        end

        -- if success then
        --     currentVideo = handleOrErr.readAll()
        --     ui.page = ui.pages.watch
        --     -- TODO: Play back the video
        -- else
        --     currentError = "Request to \""..url.."\" failed.\n"..handleOrErr
        -- end
    end,

    update = function() end,

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
            monitor.setBackgroundColor(selected and ui.colors.back.primary or ui.colors.back.secondary)
            monitor.setTextColor(selected and (clicked and ui.colors.front.primary or ui.colors.front.secondary) or ui.colors.front.text)
            monitor.write((active and "(" or "") .. tab[2] .. (active and ")" or ""))
            monitor.setBackgroundColor(ui.colors.back.clear)
            monitor.setTextColor(ui.colors.front.text)
            monitor.write(" ")
        end

        -- Always visible (bottom)
        local cursorPos = "(x".. cursor.x .. ", y" .. cursor.y ..")"
        local fancyRandom = math.random(0, 9)
        monitor.setCursorPos(1, height)
        monitor.write(cursorPos .. " | " .. (currentInfo or "empty") .. " | " .. fancyRandom)

        -- Page-specific
        if ui.page == ui.pages.home then
            monitor.setCursorPos(2, 4)
            print("Welcome to my media player!")
            print("The controls are a bit difficult to get used to, so here's some tips\n")
            print("The bottom left corner shows the position of your cursor.")
            print("The tab row is on y0 and its tabs are located under x"..#tabs.."!")
            print("")
            print("The cursor is located at x0 y0 by default, move it over to x1 y0 by pressing the right arrow key!")
        elseif ui.page == ui.pages.search then
            ui.state.searchBar.hovered = (cursor.y == 1)

            -- Draw the search box background
            monitor.setBackgroundColor(ui.state.searchBar.hovered and ui.colors.back.primary or ui.colors.back.secondary)
            for x = 1, width * 0.8, 1 do
                local char = (ui.state.searchBar.string[x] or "_")
                monitor.setCursorPos(x+1, 4)
                monitor.write(ui.state.searchBar.selected and " " or char)
            end

            -- Draw the search box text
            monitor.setCursorPos(2, 4)
            if ui.state.searchBar.string then
                monitor.write(ui.state.searchBar.string .. (#ui.state.searchBar.string > 0 and " " or ""))
            end

            -- Input handling
            if ui.state.searchBar.hovered and ui.state.searchBar.selected then
                monitor.setCursorPos(2, 4)
                ui.state.searchBar.string = read(nil, {}, nil, ui.state.searchBar.string)
                ui.state.searchBar.selected = false
                api.search_videos(ui.state.searchBar.string)
            end

            -- Video list
            local maxOnScreen = 8
            local scroll = math.max(1, cursor.y - 2)
            local y = 6
            if currentSearch ~= nil then
                for i = scroll, #currentSearch do
                    monitor.setBackgroundColor(i+2 == cursor.y+1 and ui.colors.back.primary or ui.colors.back.clear)

                    local tile = currentSearch[i]
                    if tile.type == "video" then
                        monitor.setCursorPos(4, y)
                        monitor.write(tile.title)
                        monitor.setCursorPos(4, y + 1)
                        monitor.write("-> " .. tile.author)
                        y = y + 3
                    end

                    if i > scroll + maxOnScreen then
                        break
                    end
                end
            else
                monitor.setBackgroundColor(ui.colors.back.clear)
                monitor.setCursorPos(4, y)
                if state.pleaseWait then
                    print("Searching..")
                else
                    print("Use the box above to search!")
                end
            end
        elseif ui.page == ui.pages.video then
            if currentVideo ~= nil then
                -- TODO: Fill out the video page
            else
                monitor.setCursorPos(2, 4)
                print("Select a video to view it here!")
            end
        elseif ui.page == ui.pages.settings then
            monitor.setCursorPos(2, 4)
            print("This page is unfinished!")
            monitor.setCursorPos(2, 5)
            print("Please modify the config file directly for now")
        end

        -- Always on top
        if currentError ~= nil then
            local x, y = width / 2, height / 2
            monitor.setBackgroundColor(ui.colors.back.clear2)
            monitor.clear()

            local titleText = "ERROR"
            term.setBackgroundColor(ui.colors.back.clear)
            monitor.setTextColor(colors.red)
            monitor.setCursorPos(x - (#titleText / 2), y-2)
            monitor.write(titleText)

            -- TODO: Separate the word wrapping and new line functionality into the library so it can be used everywhere
            monitor.setCursorPos(x, y)
            term.setBackgroundColor(ui.colors.back.clear2)
            local split = {}
            local current = ""
            for i = 1, #currentError do
                local char = currentError:sub(i, i)

                if char == "\n" or i+1 > #currentError or (#current > width * 0.5 and char == " ") then
                    current = current .. char
                    table.insert(split, current)
                    current = ""
                else
                    current = current .. char
                end
            end
            for i = 1, #split do
                local line = split[i]
                monitor.setCursorPos(x - (#line / 2), y + i)
                monitor.write(line)
            end
            
            local exitText = "Press any key to continue"
            monitor.setCursorPos(x - (#exitText / 2), y + #split + 2)
            monitor.setTextColor(colors.gray)
            monitor.write(exitText)
        end

        -- TODO: Use https://tweaked.cc/module/paintutils.html to draw videos
    end
}


-- Main loop
currentError = config:load()
MediaApp.start()
ui.loadBuiltinTheme(config.data.theme)
print("Starting..")
local function eventHandler()
    while state.running do
        local lastError = currentError

        local event, data1, data2 = os.pullEventRaw()
        if event == "terminate" then
            state.running = false
            return
        elseif event == "key" then
            local key, isHeld = data1, data2
            if (state.holdingCtrl and key == keys.t) or key == keys.rightShift then
                state.running = false
                return
            end
            MediaApp.input(key, isHeld)

            -- Control and shift modifiers
            state.holdingCtrl  = (not state.holdingCtrl)  and (key == keys.leftCtrl  or key == keys.rightCtrl)
            state.holdingShift = (not state.holdingShift) and (key == keys.leftShift or key == keys.rightShift)
        elseif event == "http_success" then
            local url, handle = data1, data2
            MediaApp.http(true, url, handle)
        elseif event == "http_failure" then
            local url, handle = data1, data2
            MediaApp.http(false, url, handle)
        end

        -- Error sound
        if currentError and lastError ~= currentError then
            for speaker in speakers do
                speaker.playNote("harp", 1.0, 0.8)
            end
        end
    end
end
local function updateHandler()
    while state.running do
        local lastError = currentError
        local deltaStart = os.time()

        MediaApp.update()
        for _, monitor in pairs(monitors) do
            term.redirect(monitor)
            monitor.setBackgroundColor(ui.colors.back.clear)
            monitor.setTextColor(ui.colors.front.text)
            monitor.clear()
            monitor.setCursorPos(2,2)
            MediaApp.ui(monitor)
        end

        -- Waiting between frames and calculating delta time
        sleep(time.perSecond)  -- FIXME: Try to remove sleep. It automatically rounds time.perSecond up to 0.15
        local deltaDiff = (os.time() - deltaStart)
        time.delta = deltaDiff >= 0 and deltaDiff or 0

        -- Error sound
        if currentError and lastError ~= currentError then
            for speaker in speakers do
                speaker.playNote("harp", 1.0, 0.8)
            end
        end
    end
end

-- Running the main loop
parallel.waitForAny(eventHandler, updateHandler)

-- Exiting and cleaning up after the program
MediaApp.stop()
config:save()
ui.unloadTheme()  -- Resets the colour palette
for i, monitor in pairs(monitors) do
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    monitor.setCursorPos(1,1)
end
print("Exited the media program..")
