util.ensure_package_is_installed("lua/luaffi")
local ffi = require("luaffi")

local user32 = ffi.open("user32")

if user32 == nil then
    util.toast("Error loading user32.dll library.")
    return
end

local VK_MEDIA_PLAY_PAUSE = 0xB3
local VK_MEDIA_STOP = 0xB2
local VK_MEDIA_NEXT_TRACK = 0xB0
local VK_MEDIA_PREV_TRACK = 0xB1
local VK_MEDIA_VOLUME_MUTE = 0xAD
local VK_MEDIA_VOLUME_DOWN = 0xAE
local VK_MEDIA_VOLUME_UP = 0xAF

local KEYEVENTF_KEYDOWN = 0x0000
local KEYEVENTF_KEYUP = 0x0002

local function simulate_key_press(vk_code)
    user32:call("keybd_event", vk_code, 0, KEYEVENTF_KEYDOWN, 0)
    user32:call("keybd_event", vk_code, 0, KEYEVENTF_KEYUP, 0)
end

local function SkipSong(hwnd)
    simulate_key_press(VK_MEDIA_NEXT_TRACK)
end

local function PrevSong(hwnd)
    simulate_key_press(VK_MEDIA_PREV_TRACK)
end

local function PauseSong(hwnd)
    simulate_key_press(VK_MEDIA_STOP)
end

local function ResumeSong(hwnd)
    simulate_key_press(VK_MEDIA_PLAY_PAUSE)
end

local function MuteVolume(hwnd)
    simulate_key_press(VK_MEDIA_VOLUME_MUTE)
end

local function DecreaseVolume(hwnd)
    simulate_key_press(VK_MEDIA_VOLUME_DOWN)
end

local function IncreaseVolume(hwnd)
    simulate_key_press(VK_MEDIA_VOLUME_UP)
end

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

teamchat = false
menu.toggle(menu.my_root(), "Team Chat", {""}, "Announce In Team Chat?", function(on)
    teamchat = on
end)

local hwnd = nil

menu.action(menu.my_root(), "Skip Song", {"skipsong"}, "Skip the currently playing song in Spotify", function()
    if hwnd ~= nil and hwnd ~= 0 then
        SkipSong(hwnd)
    else
        util.toast("Spotify window not found!")
    end
end)

menu.action(menu.my_root(), "Previous/Rewind Song", {"prevsong"}, "Go to the previous song in Spotify", function()
    if hwnd ~= nil and hwnd ~= 0 then
        PrevSong(hwnd)
    else
        util.toast("Spotify window not found!")
    end
end)

menu.action(menu.my_root(), "Pause Song", {"pausesong"}, "Pause the currently playing song in Spotify", function()
    if hwnd ~= nil and hwnd ~= 0 then
        PauseSong(hwnd)
    else
        util.toast("Spotify window not found!")
    end
end)

menu.action(menu.my_root(), "Resume Song", {"resumesong"}, "Resumes the currently playing song in Spotify", function()
    if hwnd ~= nil and hwnd ~= 0 then
        if GetWindowTitle(hwnd) == "Spotify" or GetWindowTitle(hwnd) == "Spotify Free" then
            ResumeSong(hwnd)
        end        
    else
        util.toast("Spotify window not found!")
    end
end)

menu.action(menu.my_root(), "Mute Volume", {"mutevolume"}, "Mute the volume (NOTE: This will mute the volume of your whole system)", function()
    if hwnd ~= nil and hwnd ~= 0 then
        MuteVolume(hwnd)
    else
        util.toast("Spotify window not found!")
    end
end)

menu.action(menu.my_root(), "Decrease Volume", {"decreasevolume"}, "Decrease the volume (NOTE: This will change the volume of your whole system)", function()
    if hwnd ~= nil and hwnd ~= 0 then
        DecreaseVolume(hwnd)
    else
        util.toast("Spotify window not found!")
    end
end)

menu.action(menu.my_root(), "Increase Volume", {"increasevolume"}, "Increase the volume (NOTE: This will change the volume of your whole system)", function()
    if hwnd ~= nil and hwnd ~= 0 then
        IncreaseVolume(hwnd)
    else
        util.toast("Spotify window not found!")
    end
end)

local function MonitorSpotifyTitle()
    ::jump::

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