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

local function utf16_to_utf8(ptr, length)
    local utf8 = {}
    for i = 0, length - 1 do
        local wchar = memory.read_ushort(ptr + i * 2)
        if wchar == 0 then break end

        if wchar < 0x80 then
            table.insert(utf8, string.char(wchar))
        elseif wchar < 0x800 then
            table.insert(utf8, string.char(0xC0 | (wchar >> 6)))
            table.insert(utf8, string.char(0x80 | (wchar & 0x3F)))
        else
            table.insert(utf8, string.char(0xE0 | (wchar >> 12)))
            table.insert(utf8, string.char(0x80 | ((wchar >> 6) & 0x3F)))
            table.insert(utf8, string.char(0x80 | (wchar & 0x3F)))
        end
    end
    return table.concat(utf8)
end

local function GetWindowTitle(hwnd)
    local title = memory.alloc(512 * 2)
    local length = user32:call("GetWindowTextW", hwnd, title, 512)

    if length > 0 then  
        return utf16_to_utf8(title, length)
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
            if currentTitle == "Spotify" or currentTitle == "Spotify Free" then goto jump_1 end
            lastTitle = currentTitle

            util.toast("Current Title: " .. currentTitle)

            chat.send_message("Currently listening to: " .. currentTitle, teamchat, true, true)
            ::jump_1::
        end

        util.yield(1000)
    end
end

MonitorSpotifyTitle()