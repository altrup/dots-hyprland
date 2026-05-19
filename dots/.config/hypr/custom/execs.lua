-- Input method
hl.on("hyprland.start", function()
    hl.dsp.exec_cmd("fcitx5")
    hl.dsp.exec_cmd("hyprpm reload")
    hl.dsp.exec_cmd("nm-applet --indicator")
    hl.dsp.exec_cmd("sleep 1 && iio-hyprland")
end)