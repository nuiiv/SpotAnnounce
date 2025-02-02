util.ensure_package_is_installed("lua/luaffi")
local ffi = require("luaffi")

local user32 = ffi.open("user32")

if user32 == nil then
    util.toast("Error loading user32.dll library.")
    return
end

teamchat = false
menu.toggle(menu.my_root(), "Team Chat", {""}, "Announce In Team Chat?", function(on)
    teamchat = on
end)

local function GetWindowTitle(hwnd)
    local title = memory.alloc(256)
    local length = user32:call("GetWindowTextA", hwnd, title, 256)
    if length > 0 then
        return memory.read_string(title, length)
    end
    return ""
end

local function MonitorSpotifyTitle()
    ::jump::
    
    local hwnd = nil

    while true do
        hwnd = user32:call("FindWindowA", 0, "Spotify")
        if hwnd == 0 then
            hwnd = user32:call("FindWindowA", 0, "Spotify Free")
        end
        if hwnd ~= 0 then
            break
        end
        util.toast("Waiting for Spotify window... (Pause current song if you are playing one.)")
        util.yield(1000)
    end    

    util.toast("Found Spotify Window - Monitoring...")
    local lastTitle = GetWindowTitle(hwnd)

    while true do
        if hwnd == 0 then
            util.toast("Spotify window closed. Restarting monitoring...")
            goto jump
        end

        local currentTitle = GetWindowTitle(hwnd)

        if currentTitle == "" then
            util.toast("Spotify window closed. Restarting monitoring...")
            goto jump
        end

        if currentTitle ~= lastTitle then
            if currentTitle == "Spotify" then goto jump_1 end
            lastTitle = currentTitle

            util.toast("Current Title: " .. currentTitle)

            chat.send_message("Currently listening to: " .. currentTitle, teamchat, true, true)
            ::jump_1::
        end

        util.yield(1000)
    end
end

MonitorSpotifyTitle()