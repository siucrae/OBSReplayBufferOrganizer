obs = obslua
ffi = require("ffi")

-- Tell LuaJIT FFI about the DLL function
ffi.cdef[[
    int get_running_fullscreen_game_path(char* buffer, int bufferSize);
]]

-- Load the DLL (make sure it's in the same folder as this script)
detect_game = ffi.load(script_path() .. "detect_game.dll")

-- Script description in OBS
function script_description()
    return [[
Saves replays to sub-folders using the currently focused application's executable name.

Author: redraskal
Modified by: siucrae
]]
end

-- Add a callback for OBS frontend events (when replay buffer is saved)
function script_load()
    obs.obs_frontend_add_event_callback(obs_frontend_callback)
end

-- OBS event callback
function obs_frontend_callback(event)
    if event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then
        local path = get_replay_buffer_output()
        local folder = get_running_game_title()
        if path ~= nil and folder ~= nil then
            print("Moving " .. path .. " to " .. folder)
            move(path, folder)
        end
    end
end

-- Get the path of the last replay buffer
function get_replay_buffer_output()
    local replay_buffer = obs.obs_frontend_get_replay_buffer_output()
    local cd = obs.calldata_create()
    local ph = obs.obs_output_get_proc_handler(replay_buffer)
    obs.proc_handler_call(ph, "get_last_replay", cd)
    local path = obs.calldata_string(cd, "path")
    obs.calldata_destroy(cd)
    obs.obs_output_release(replay_buffer)
    return path
end

-- Get the currently focused application's executable name
function get_running_game_title()
    local buffer = ffi.new("char[?]", 260)
    local result = detect_game.get_running_fullscreen_game_path(buffer, 260)
    if result ~= 0 then
        return nil
    end

    local full_path = ffi.string(buffer)
    if #full_path == 0 then
        return nil
    end

    -- Extract just the executable name (strip path)
    local exe_name = full_path:match("([^\\]+)$")
    return exe_name
end

-- Move replay to a folder named after the application
function move(path, folder)
    local sep = string.match(path, "^.*()/") -- get last separator index
    local root = string.sub(path, 1, sep) .. folder
    local file_name = string.sub(path, sep + 1)
    local adjusted_path = root .. "\\" .. file_name

    if obs.os_file_exists(root) == false then
        obs.os_mkdir(root)
    end

    obs.os_rename(path, adjusted_path)
end
