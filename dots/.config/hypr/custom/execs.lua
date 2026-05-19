-- Input method
hl.on("hyprland.start", function()
    hl.dsp.exec_cmd("fcitx5")
    hl.dsp.exec_cmd("hyprpm reload")
    hl.dsp.exec_cmd("nm-applet --indicator")
end)