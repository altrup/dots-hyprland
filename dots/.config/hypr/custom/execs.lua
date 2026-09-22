hl.on("hyprland.start", function()
    hl.exec_cmd("fcitx5")
    hl.exec_cmd("hyprpm reload")
    hl.exec_cmd("sleep 2 && nm-applet --indicator")
    hl.exec_cmd("input-remapper-control --command autoload")
    -- XWayland apps (MATLAB, Chromium/CEF) read Xft.dpi; force_zero_scaling leaves them at 1x otherwise
    hl.exec_cmd([[echo "Xft.dpi: $(hyprctl -j monitors | jq -r '.[] | select(.focused) | .scale * 96 | round')" | xrdb -merge]])
end)