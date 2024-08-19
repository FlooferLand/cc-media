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
paths.jsonlib = fs.combine(paths.folders.install, "lib", "json.lua")

-- Utility
local function install(path, link)
    local req = http.get(link)
    local f = fs.open(path, 'w')
    f.write(req.readAll())
    f.close()
    req.close()
end

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
if not fs.exists(".devenv") then
    install(paths.program, "https://raw.githubusercontent.com/FlooferLand/cc-media/main/media/program.lua")
    install(paths.library, "https://raw.githubusercontent.com/FlooferLand/cc-media/main/media/library.lua")
else
    print("Developer environment detected")
end
install(paths.jsonlib, "https://gist.githubusercontent.com/tylerneylon/59f4bcf316be525b30ab/raw/7f69cc2cea38bf68298ed3dbfc39d197d53c80de/json.lua")

-- Running the program
shell.run(paths.program)

