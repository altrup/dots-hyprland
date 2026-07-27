-- Shared lid-switch state, used by custom/keybinds.lua
local M = {}

local last_lid_monitor = nil

function M.is_lid_closed()
    for _, path in ipairs({ "/proc/acpi/button/lid/LID/state", "/proc/acpi/button/lid/LID0/state" }) do
        local f = io.open(path, "r")
        if f then
            local content = f:read("*a")
            f:close()
            return content:match("closed") ~= nil
        end
    end
    return false
end

-- NOTE: hl.get_monitors() only lists active monitors, so a disabled one can't
-- be looked up by name on re-enable - remember it instead. Re-enabling also
-- requires disabled = false explicitly; omitting the field doesn't clear it
function M.disable_internal_if_external_present()
    local monitors = hl.get_monitors()
    if #monitors < 2 then return false end
    for _, m in ipairs(monitors) do
        if m.name:match("^eDP%-") then
            last_lid_monitor = m.name
            hl.monitor({ output = m.name, disabled = true })
            return true
        end
    end
    return false
end

function M.get_last_lid_monitor()
    return last_lid_monitor
end

-- Skips internal-panel rules while the lid is closed - re-enabling eDP with the
-- lid shut power-cycles the panel and wedges the display engine. Guard lives here
-- because nwg-displays regenerates monitors.lua and discards edits to it
function M.load_monitors()
    local path = HOME .. "/.config/hypr/monitors.lua"
    -- hyprland.lua requires "monitors" after custom/ is sourced; claiming the
    -- slot makes that a no-op so the rules only ever land through here
    package.loaded["monitors"] = true
    if not is_file_exists(path) then return end
    if not M.is_lid_closed() then
        dofile(path)
        return
    end
    -- Shimmed through the chunk's environment; `hl` is native and may not be writable
    local shim = setmetatable({
        monitor = function(rule)
            if not (type(rule) == "table" and tostring(rule.output):match("^eDP%-")) then
                hl.monitor(rule)
            end
        end,
    }, { __index = hl })
    assert(loadfile(path, "t", setmetatable({ hl = shim }, { __index = _G })))()
end

return M
