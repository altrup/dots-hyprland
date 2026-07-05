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

`lidstate.lua` holds the shared state (`is_lid_closed`,
`disable_internal_if_external_present`, `get_last_lid_monitor`) because two
independent files need it:

- `keybinds.lua` — reacts to the physical lid switch and to `config.reloaded`.
- `~/.config/hypr/monitors.lua` (machine-specific, not tracked in this repo)
  — must call `require("custom.lidstate").is_lid_closed()` before enabling
  the internal panel's `hl.monitor({...})` rule, and skip it (or pass
  `disabled = true`) when the lid is closed.

**Why `monitors.lua` needs the check too:** `hyprctl reload` re-sources
`monitors.lua` unconditionally. If `monitors.lua` doesn't guard the internal
panel itself, reloading while the lid is closed re-enables it, then
`keybinds.lua`'s `config.reloaded` handler disables it again a moment later —
visible as the panel flashing on and off, and workspaces migrating onto and
back off the panel each time. The `config.reloaded` handler in `keybinds.lua`
is a safety net for configs that skip the guard, not the primary fix.
