obs = obslua
ffi = require("ffi")

-- load the shared object (detect_game.dll)
ffi.cdef[[
    int get_running_game_path(char* buffer, int bufferSize);
]]

-- load the detect_game.dll file (make sure its in the same directory as the lua script or specify the correct path)
detect_game = ffi.load(script_path() .. "detect_game.dll")

-- description in obs
function script_description()
return [[Saves replays to sub-folders using the current fullscreen/focused video game executable name on Windows.

Author: redraskal
(original)
Modified by: siucrae
]]
end

-- add a callback for frontend events in OBS (when a replay buffer is saved)
function script_load()
obs.obs_frontend_add_event_callback(obs_frontend_callback)
end

-- callback to process events triggered by OBS
function obs_frontend_callback(event)
if event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then
    local path = get_replay_buffer_output()             -- get the path to the replay buffer output
    local folder = get_running_game_title()             -- get the game title from the shared object (detect_game.dll)
	if path ~= nil and folder ~= nil then               -- if both the replay path and folder/game title are valid then move the file
    	print("Moving " .. path .. " to " .. folder)    -- move the replay file to the appropriate folder
        move(path, folder)
        end
    end
end

-- retrieve the path of the latest replay buffer saved in obs
function get_replay_buffer_output()
	local replay_buffer = obs.obs_frontend_get_replay_buffer_output()   -- get the replay buffer object
    local cd = obs.calldata_create()                                    -- create an empty calldata object for passing data
    local ph = obs.obs_output_get_proc_handler(replay_buffer)           -- get the process handler for the replay buffer
    obs.proc_handler_call(ph, "get_last_replay", cd)                    -- call the process handler to get the last saved replay
	local path = obs.calldata_string(cd, "path")                        -- retrieve the path of the replay from calldata
	obs.calldata_destroy(cd)                                            -- clean up the calldata object
    obs.obs_output_release(replay_buffer)                               -- release the replay buffer
    return path
end

-- function to get the running games title using the shared object (detect_game.dll)
function get_running_game_title()
    local path = ffi.new("char[?]", 260)                            -- allocate a buffer to store the game path
    local result = detect_game.get_running_game_path(path, 260)     -- call the function from the .dll library to get the running games path

    -- if there was an error or the game path is not available then return nil
    if result ~= 0 then
        return nil
    end

    -- convert the result from C string to lua string
	result = ffi.string(path)
    local len = #result

    -- if the path length is zero/no game detected then return nil
    if len == 0 then
        return nil
    end

    return result
    end

-- function to move the replay file to a new folder based on the game title
function move(path, folder)
    local sep = string.match(path, "^.*()[/\\]")  -- works for both / and \
    if sep == nil then return end

    local base_dir = string.sub(path, 1, sep)
    local filename = string.sub(path, sep + 1)

    local new_folder = base_dir .. folder
    local new_path = new_folder .. "\\" .. filename

    if not obs.os_file_exists(new_folder) then
        obs.os_mkdir(new_folder)
    end

	-- rename/move the file to the new location
    obs.os_rename(path, new_path)
end
