hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )
hl.bind("XF86PowerOff", hl.dsp.global("quickshell:sessionToggle"), { locked = true, description = "Toggle Session Menu" } )

hl.unbind("SUPER + O")
hl.bind("SUPER + O", hl.dsp.global("quickshell:overlayToggle"), { description = "Shell: Toggle overlay" })