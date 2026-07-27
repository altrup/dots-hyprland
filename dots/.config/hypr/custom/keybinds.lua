hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )
hl.bind("XF86PowerOff", hl.dsp.global("quickshell:sessionToggle"), { locked = true, description = "Toggle Session Menu" } )

hl.unbind("SUPER + O")
hl.bind("SUPER + O", hl.dsp.global("quickshell:overlayToggle"), { description = "Shell: Toggle overlay" })

-- Lid switch: disable/enable internal display (Hyprland migrates workspaces automatically)
-- Requires HandleLidSwitch=ignore in /etc/systemd/logind.conf.d/lid.conf
-- NOTE: must use hl.get_monitors() (native), not io.popen("hyprctl ...") --
-- shelling out to hyprctl from inside a bind callback deadlocks Hyprland's
-- main thread, since hyprctl's IPC request needs that same thread to respond
local lidstate = require("custom.lidstate")

lidstate.load_monitors()

hl.bind("switch:on:Lid Switch", function()
    -- Don't disable the internal panel if it's the only display - that would
    -- leave Hyprland with zero outputs. Suspend instead, like default lid behavior
    -- (before_sleep_cmd/after_sleep_cmd in hypridle.conf handle lock/unlock)
    if not lidstate.disable_internal_if_external_present() then
        hl.dispatch(hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"))
    end
end, { locked = true })

-- Safety net for anything that enables the internal panel outside the config
-- load path, such as a hyprctl keyword. lidstate.load_monitors() already filters
-- monitors.lua, so a plain reload leaves this a no-op
hl.on("config.reloaded", function()
    if lidstate.is_lid_closed() then lidstate.disable_internal_if_external_present() end
end)

hl.bind("switch:off:Lid Switch", function()
    local last_lid_monitor = lidstate.get_last_lid_monitor()
    if last_lid_monitor then
        hl.monitor({ output = last_lid_monitor, disabled = false, mode = "preferred", position = "auto", scale = 1 })
    end
    lidstate.load_monitors()
end, { locked = true })