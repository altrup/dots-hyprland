hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
    debug = {
        disable_scale_checks = true,
    },
    general = {
        -- Gaps and border
        gaps_in = 2.5,
    },
})

hl.gesture({
    fingers = 4,
    direction = "vertical",
    action = "special",
    workspace_name = "special",
})
hl.gesture({ fingers = 4, direction = "up", action = "unset" })
hl.gesture({ fingers = 4, direction = "down", action = "unset" })

hl.device({
    name = "logitech-g305-1",
    sensitivity = -0.6,
})

-- # Hyprgrass
hl.config({
    plugin = {
        hyprgrass = {
            sensitivity = 5.0,
            long_press_delay = 500,
            resize_on_border_long_press = true,
            edge_margin = 10,
        },
    },
})

-- tap with 2 fingers
hl.plugin.hyprgrass.bind {
    pattern = {kind = "tap", fingers = 2},
    action = hl.dsp.exec_cmd("ydotool click 0xC1"),
}

-- tap with 3 fingers
hl.plugin.hyprgrass.bind {
    pattern = {kind = "tap", fingers = 3},
    action = hl.dsp.global("quickshell:oskToggle"),
}

-- ==== Window Management ====
hl.plugin.hyprgrass.bind {
    pattern = {kind = "longpress", fingers = 2},
    mouse = true,
    action = hl.dsp.window.drag(),
}
hl.plugin.hyprgrass.bind {
    pattern = {kind = "longpress", fingers = 3},
    mouse = true,
    action = hl.dsp.window.resize(),
}

-- swipe right with 3 fingers: fullscreen
hl.plugin.hyprgrass.gesture {
    pattern = {kind = "swipe", fingers = 3, direction = "right"},
    action = "fullscreen",
}

-- swipe left with 3 fingers: maximize
hl.plugin.hyprgrass.bind {
    pattern = {kind = "swipe", fingers = 3, direction = "left"},
    action = hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
}
-- hl.plugin.hyprgrass.gesture {
--     pattern = {kind = "swipe", fingers = 3, direction = "left"},
--     action = "fullscreen",
--     mode = "maximize",
-- }
-- doesn't work rn for some reason

-- swipe up with 3 fingers: float
hl.plugin.hyprgrass.gesture {
    pattern = {kind = "swipe", fingers = 3, direction = "up"},
    action = "float",
}

-- swipe down with 3 fingers
hl.plugin.hyprgrass.gesture {
    pattern = {kind = "swipe", fingers = 3, direction = "down"},
    action = "close",
}

-- ==== Workspace Management ====
-- swipe up/down with 5 fingers: toggle scratchpad
hl.plugin.hyprgrass.gesture {
    pattern = {kind = "swipe", fingers = 5, direction = "vertical"},
    action = "special",
    workspace_name = "special",
}

-- swipe left/right with 5 fingers: switch workspace
hl.plugin.hyprgrass.gesture {
    pattern = {kind = "swipe", fingers = 5, direction = "horizontal"},
    action = "workspace",
}

-- swipe up/down with 4 fingers: send to/off scratchpad
hl.plugin.hyprgrass.bind {
    pattern = {kind = "swipe", fingers = 4, direction = "up"},
    action = hl.dsp.window.move({ workspace = "e+0" }),
}
hl.plugin.hyprgrass.bind {
    pattern = {kind = "swipe", fingers = 4, direction = "down"},
    action = hl.dsp.window.move({ workspace = "special:special" }),
}

-- swipe left/right with 4 fingers: send to neighboring workspace
hl.plugin.hyprgrass.bind {
    pattern = {kind = "swipe", fingers = 4, direction = "left"},
    action = hl.dsp.window.move({ workspace = "r-1" }),
}
hl.plugin.hyprgrass.bind {
    pattern = {kind = "swipe", fingers = 4, direction = "right"},
    action = hl.dsp.window.move({ workspace = "r+1" }),
}

-- swipe towards center from left/right edge: switch workspace
hl.plugin.hyprgrass.gesture {
    pattern = {kind = "edge", origin = "left", direction = "horizontal"},
    action = "workspace",
}
hl.plugin.hyprgrass.gesture {
    pattern = {kind = "edge", origin = "right", direction = "horizontal"},
    action = "workspace",
}
hl.plugin.hyprgrass.bind {
    pattern = {kind = "edge", origin = "left", direction = "right"},
    action = hl.dsp.focus({ workspace = "r-1" }),
}
hl.plugin.hyprgrass.bind {
    pattern = {kind = "edge", origin = "right", direction = "left"},
    action = hl.dsp.focus({ workspace = "r+1" }),
}

-- swipe down from top edge: toggle search
hl.plugin.hyprgrass.bind {
    pattern = {kind = "edge", origin = "up", direction = "down"},
    action = hl.dsp.exec_cmd("qs -c $qsConfig ipc call search toggle"),
}

-- swipe from top edge horizontally: switch workspace
hl.plugin.hyprgrass.gesture {
    pattern = {kind = "edge", origin = "up", direction = "horizontal"},
    action = "workspace",
}

-- swipe up from bottom edge: toggle scratchpad
hl.plugin.hyprgrass.bind {
    pattern = {kind = "edge", origin = "down", direction = "up"},
    action = hl.dsp.workspace.toggle_special("special"),
}

-- swipe horizontally along bottom edge: switch workspace
hl.plugin.hyprgrass.gesture {
    pattern = {kind = "edge", origin = "down", direction = "horizontal"},
    action = "workspace",
}

-- ==== App Management ====
hl.plugin.hyprgrass.bind {
    pattern = {kind = "edge", origin = "left", direction = "up"},
    action = hl.dsp.exec_cmd(browser),
}
hl.plugin.hyprgrass.bind {
    pattern = {kind = "edge", origin = "left", direction = "down"},
    action = hl.dsp.exec_cmd(textEditor),
}
hl.plugin.hyprgrass.bind {
    pattern = {kind = "edge", origin = "right", direction = "up"},
    action = hl.dsp.exec_cmd(fileManager),
}
hl.plugin.hyprgrass.bind {
    pattern = {kind = "edge", origin = "right", direction = "down"},
    action = hl.dsp.exec_cmd(terminal),
}