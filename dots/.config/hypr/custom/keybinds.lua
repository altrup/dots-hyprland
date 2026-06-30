hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )
hl.bind("XF86PowerOff", hl.dsp.global("quickshell:sessionToggle"), { locked = true, description = "Toggle Session Menu" } )

hl.unbind("SUPER + O")
hl.bind("SUPER + O", hl.dsp.global("quickshell:overlayToggle"), { description = "Shell: Toggle overlay" })

-- Lid switch: disable/enable internal display (Hyprland migrates workspaces automatically)
-- Requires HandleLidSwitch=ignore in /etc/systemd/logind.conf.d/lid.conf
-- NOTE: must use hl.get_monitors() (native), not io.popen("hyprctl ...") --
-- shelling out to hyprctl from inside a bind callback deadlocks Hyprland's
-- main thread, since hyprctl's IPC request needs that same thread to respond
-- NOTE: hl.get_monitors() only lists active monitors, so a disabled one can't
-- be looked up by name on re-enable - remember it instead. Re-enabling also
-- requires disabled = false explicitly; omitting the field doesn't clear it
local last_lid_monitor = nil

local function is_lid_closed()
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

local function disable_internal_if_external_present()
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

hl.bind("switch:on:Lid Switch", function()
    -- Don't disable the internal panel if it's the only display - that would
    -- leave Hyprland with zero outputs. Suspend instead, like default lid behavior
    -- (before_sleep_cmd/after_sleep_cmd in hypridle.conf handle lock/unlock)
    if not disable_internal_if_external_present() then
        hl.dispatch(hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"))
    end
end, { locked = true })

-- `hyprctl reload` re-sources monitors.lua unconditionally, which would
-- re-enable the internal panel even if the lid is still physically closed
hl.on("config.reloaded", function()
    if is_lid_closed() then disable_internal_if_external_present() end
end)

hl.bind("switch:off:Lid Switch", function()
    if last_lid_monitor then
        hl.monitor({ output = last_lid_monitor, disabled = false, mode = "preferred", position = "auto", scale = 1 })
    end
    local monitorsFile = HOME .. "/.config/hypr/monitors.lua"
    if is_file_exists(monitorsFile) then dofile(monitorsFile) end
end, { locked = true })