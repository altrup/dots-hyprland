-- Shared lid-switch state, used by custom/keybinds.lua (event handlers) and
-- monitors.lua (so it can skip re-enabling the internal panel on config
-- reload while the lid is closed, instead of enabling then immediately
-- disabling it again)
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

return M
