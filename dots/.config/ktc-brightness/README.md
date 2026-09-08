# KTC virtual brightness

`dots/.local/bin/ddcutil` wraps the real executable. It translates brightness
only for the configured manufacturer, model, and product code. Python 3.10+
and Linux are required. Quickshell's brightness logic is unchanged.

## Measure before installation

Menu-labeled F4 readings on this M27T6S gave Off = 0, Low = 4,
Standard = 2, and High = 3. These values are saved in `config.json`.
F4 writes have not been tested on the monitor.
Brightness reads and writes for the KTC fail if any mode value is `null`.
Detection, other monitors, and unrelated controls still use the real ddcutil.

Use `/usr/bin/ddcutil detect` to find the current bus. For each menu setting
(Off, Low, Standard, High), read F4 with the real executable:

```sh
/usr/bin/ddcutil --noconfig --disable-udf --bus BUS getvcp F4 --brief
```

Record the last byte in `VCP F4 CNC x00 x05 x00 xNN` as a decimal integer in
the matching band's `local_dimming` field. Do not infer the codes from menu
order. Auto has no band. Test the observed codes with readback and a menu
check before enabling the wrapper.

## Installation

Check that `real_ddcutil` names the real executable by absolute path. Both
dotfiles installation paths include the wrapper. To install only this utility
after calibration, run from the repository root:

```sh
install -Dm755 dots/.local/bin/ddcutil ~/.local/bin/ddcutil
install -Dm644 dots/.config/ktc-brightness/config.json ~/.config/ktc-brightness/config.json
```

The repository's Hyprland environment already prepends `~/.local/bin` to
PATH. Start a new session if the running session does not have that PATH.
Quickshell and other callers must resolve `ddcutil` to `~/.local/bin/ddcutil`.
An absolute call to the real executable or a direct libddcutil call bypasses it.

## Behavior

| Virtual brightness | Dimming | Hardware mapping |
| --- | --- | --- |
| 0 through 25 | High | 0 through 100 |
| Above 25 through 50 | Standard | 0 through 100 |
| Above 50 through 75 | Low | 0 through 100 |
| Above 75 through 100 | Off | 0 through 100 |

The lower band owns each exact boundary. Values are integers and rounding
uses the nearest hardware value, with ties rounded up. Thus 25 means High/100,
26 means Standard/4, and 50 means Standard/100. Each band restarts its hardware
range: perceived brightness can jump or increase when the slider decreases.
The configurable `hardware` limits allow later tuning.

Use the usual `getvcp 10` and `setvcp 10 VALUE` commands. Brightness reads
report virtual values with maximum 100, including brief output and grouped
reads such as `getvcp COLOR`. Bus, display, manufacturer, model, serial, and
EDID selectors are supported. An ambiguous selection is rejected. Set virtual
brightness separately from other VCP writes. Relative `setvcp 10 + VALUE`
and `setvcp 10 - VALUE` commands clamp to 0–100. Brightness write options are
limited to the supported selectors, output flags, verification flags,
`--sleep-multiplier`, and `--maxtries`; unsupported options are rejected.

Bus-only commands verify monitor identity from the kernel's connector and EDID
files, without a full `ddcutil detect` call. Missing, invalid, or ambiguous
kernel data falls back to detection. Other selectors also use detection.
Hardware settings are still read before and after each write.

Writes hold a monitor-specific lock. Pending absolute writes skip values
superseded by a newer request; relative writes are serialized individually.
Local dimming changes precede hardware brightness changes in both directions. Both
settings are read back before state is saved, even with `--noverify`.
A partial failure reports an error and discards the saved value.

State and locks live in `$XDG_STATE_HOME/ktc-brightness` (default
`~/.local/state/ktc-brightness`). Hardware is read again after restarts and
manual changes. Saved virtual values are reused only when they map to the
observed settings. An unconfigured mode such as Auto causes brightness reads
to fail; an absolute brightness write selects a configured mode.

Quickshell's existing minimum outgoing value is 1. The wrapper keeps 1 distinct
from 0. Anti-flashbang writes use these same bands and can cross boundaries.
