hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )
hl.bind("XF86PowerOff", hl.dsp.global("quickshell:sessionToggle"), { locked = true, description = "Toggle Session Menu" } )

hl.unbind("SUPER + O")
hl.bind("SUPER + O", hl.dsp.global("quickshell:overlayToggle"), { description = "Shell: Toggle overlay" })

-- Toggle external monitor input source between DisplayPort and HDMI
hl.bind("SUPER + F1", function()
    local p = io.popen("ddcutil getvcp 60 --brief")
    local out = p:read("*a")
    p:close()
    local target = out:match("x0f%s*$") and "0x11" or "0x0f"
    hl.exec_cmd("ddcutil setvcp 60 " .. target)
end, { locked = true, description = "Toggle monitor input source" })

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
    -- Pass lid state from the event itself - the ACPI file can still read
    -- "closed" while resuming from a wake triggered by this very lid open
    lidstate.load_monitors(false)
end, { locked = true })