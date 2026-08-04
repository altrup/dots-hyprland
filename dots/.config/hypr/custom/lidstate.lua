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
-- Reports success when an external output exists, even if the internal panel is
-- already disabled - counting active monitors instead would read the second call
-- as "internal is the only display" and suspend
function M.disable_internal_if_external_present()
    local internal, has_external
    for _, m in ipairs(hl.get_monitors()) do
        if m.name:match("^eDP%-") then internal = m.name else has_external = true end
    end
    if not has_external then return false end
    if internal then
        last_lid_monitor = internal
        hl.monitor({ output = internal, disabled = true })
    end
    return true
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
            if type(rule) == "table" and tostring(rule.output):match("^eDP%-") then
                -- Dropping the rule entirely would let the panel fall back to its
                -- enabled default, so every reload would flap the output off and on
                hl.monitor({ output = rule.output, disabled = true })
            else
                hl.monitor(rule)
            end
        end,
    }, { __index = hl })
    assert(loadfile(path, "t", setmetatable({ hl = shim }, { __index = _G })))()
end

return M
