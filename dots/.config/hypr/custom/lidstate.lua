-- Shared lid-switch helpers, used by custom/keybinds.lua
local M = {}

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
        hl.monitor({ output = internal, disabled = true })
    end
    return true
end

-- hl.get_monitors() only lists active monitors, so a disabled panel can't be
-- looked up there on re-enable - fall back to the DRM connector name in sysfs
-- (Hyprland output names match DRM connector names)
local function sysfs_internal_name()
    local p = io.popen("ls /sys/class/drm 2>/dev/null")
    if not p then return nil end
    for line in p:lines() do
        local name = line:match("^card%d+%-(eDP%-%d+)$")
        if name then
            -- Dual-GPU machines expose the panel on every card; only the card
            -- it's wired to reads "connected"
            local s = io.open("/sys/class/drm/" .. line .. "/status", "r")
            local connected = s and s:read("*a"):match("^connected")
            if s then s:close() end
            if connected then
                p:close()
                return name
            end
        end
    end
    p:close()
    return nil
end

-- Applies monitors.lua with the internal-panel rules rewritten for the lid
-- state: forced disabled while closed (re-enabling eDP with the lid shut
-- power-cycles the panel and wedges the display engine), forced enabled while
-- open (a rule that omits `disabled` doesn't clear a previous disabled = true,
-- which would leave the panel dark forever). The rewrite lives here because
-- nwg-displays regenerates monitors.lua and discards edits to it.
-- `closed` overrides the ACPI lid state - the switch binds pass the state from
-- the event itself, since the ACPI file can lag behind on resume
function M.load_monitors(closed)
    if closed == nil then closed = M.is_lid_closed() end
    local path = HOME .. "/.config/hypr/monitors.lua"
    -- hyprland.lua requires "monitors" after custom/ is sourced; claiming the
    -- slot makes that a no-op so the rules only ever land through here
    package.loaded["monitors"] = true
    if not is_file_exists(path) then
        local internal = not closed and sysfs_internal_name() or nil
        if internal then
            hl.monitor({ output = internal, disabled = false, mode = "preferred", position = "auto", scale = 1 })
        end
        return
    end
    -- Shimmed through the chunk's environment; `hl` is native and may not be writable
    local shim = setmetatable({
        monitor = function(rule)
            if type(rule) == "table" and tostring(rule.output):match("^eDP%-") then
                if closed then
                    -- Dropping the rule entirely would let the panel fall back to its
                    -- enabled default, so every reload would flap the output off and on
                    hl.monitor({ output = rule.output, disabled = true })
                else
                    rule.disabled = false
                    hl.monitor(rule)
                end
            else
                hl.monitor(rule)
            end
        end,
    }, { __index = hl })
    assert(loadfile(path, "t", setmetatable({ hl = shim }, { __index = _G })))()
end

return M
