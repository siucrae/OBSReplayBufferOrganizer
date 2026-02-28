obs = obslua
ffi = require("ffi")
bit = require("bit")

ffi.cdef[[
typedef void* HANDLE;
typedef void* HWND;
typedef unsigned long DWORD;
typedef int BOOL;

HWND GetForegroundWindow(void);
DWORD GetWindowThreadProcessId(HWND hWnd, DWORD *lpdwProcessId);
HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId);
BOOL CloseHandle(HANDLE hObject);
DWORD GetModuleBaseNameA(HANDLE hProcess, void* hModule, char* lpBaseName, DWORD nSize);
]]

local user32 = ffi.load("user32")
local kernel32 = ffi.load("kernel32")
local psapi = ffi.load("psapi")

local PROCESS_QUERY_INFORMATION = 0x0400
local PROCESS_VM_READ = 0x0010

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
    local folder = get_focused_process_name()             -- get the game title from the shared object (detect_game.dll)
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

function get_focused_process_name()
    local hwnd = user32.GetForegroundWindow()
    if hwnd == nil then return nil end

    local pid = ffi.new("DWORD[1]")
    user32.GetWindowThreadProcessId(hwnd, pid)
    if pid[0] == 0 then return nil end

    local process = kernel32.OpenProcess(
        bit.bor(PROCESS_QUERY_INFORMATION, PROCESS_VM_READ),
        false,
        pid[0]
    )

    if process == nil then return nil end
	
    local buffer = ffi.new("char[260]")
    local result = psapi.GetModuleBaseNameA(process, nil, buffer, 260)

    kernel32.CloseHandle(process)

    if result == 0 then return nil end

    local name = ffi.string(buffer)

    -- remove .exe extension
    name = string.gsub(name, "%.exe$", "")

    return name
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
