# custom/

Personal overrides layered on top of the upstream Hyprland Lua config. Files
here are `require`d/sourced from the main config and can freely reference
each other via `require("custom.<name>")`.

## Lid switch (`keybinds.lua` + `lidstate.lua`)

Closing the lid disables the internal panel (instead of the default suspend)
whenever an external monitor is present, so Hyprland can migrate workspaces
onto the external display and keep working. With no external monitor, it
falls back to `systemctl suspend`. Requires `HandleLidSwitch=ignore` in
`/etc/systemd/logind.conf.d/lid.conf`, otherwise systemd suspends before the
`switch:on:Lid Switch` handler runs.

- `keybinds.lua` — reacts to the physical lid switch and to `config.reloaded`.
- `lidstate.lua` — `is_lid_closed`, `disable_internal_if_external_present`,
  and `load_monitors`, which applies `~/.config/hypr/monitors.lua`
  (machine-specific, not tracked in this repo) with the internal-panel rules
  rewritten to match the lid state: forced off while closed, forced on while
  open. Rewriting on open matters because a rule that omits `disabled` doesn't
  clear a previous `disabled = true`, which would leave the panel dark after
  it was turned off by a lid close. Without a `monitors.lua`, the eDP
  connector name comes from `/sys/class/drm` instead. The design is stateless:
  lid open recovers from any prior state, including a stale ACPI lid reading
  while resuming from a wake triggered by the lid open itself (the switch
  binds pass the lid state from the event rather than polling ACPI).

`monitors.lua` itself needs no lid guard — `load_monitors` claims the
`monitors` module slot, so its rules only ever land through the rewrite, on
startup and on `hyprctl reload` alike. The `config.reloaded` handler in
`keybinds.lua` is a safety net for anything that enables the panel outside
the config load path, such as a `hyprctl keyword`.
