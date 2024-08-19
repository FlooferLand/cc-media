-- Launcher for the media software

-- Paths
local paths = {}
paths.folders = {}
paths.folders.install = "/media/"
paths.folders.libs = fs.combine(paths.folders.install, "lib/")
paths.folders.localSongs = fs.combine(paths.folders.install, "songs/")
paths.drive = "hdd"
paths.program = fs.combine(paths.folders.install, "program.lua")
paths.library = fs.combine(paths.folders.install, "library.lua")
paths.jsonlib = fs.combine(paths.folders.install, "json.lua")

-- Variables
local programPastebin = "(FILL THIS OUT WITH THE HASH)"
local libraryPastebin = "(FILL THIS OUT WITH THE HASH)"

-- Making the folders
for i, path in pairs(paths.folders) do
    if not fs.isDir(path) then
        print("Making '"..path.."' folder..")
        fs.makeDir(path)
    end
end

-- Extra files
local f = fs.open(fs.combine(paths.folders.localSongs, "PUT FILES HERE.txt"), 'w')
f.close()

-- Install libraries
local req = http.get("https://gist.githubusercontent.com/tylerneylon/59f4bcf316be525b30ab/raw/7f69cc2cea38bf68298ed3dbfc39d197d53c80de/json.lua")
local f = fs.open(paths.jsonlib, 'w')
f.write(req.readAll())
f.close()
req.close()
-- shell.run("pastebin get "..libraryPastebin.." "..paths.library)

-- Install program
-- shell.run("pastebin get "..programPastebin.." "..paths.program)

-- Running the program
shell.run(paths.program)

