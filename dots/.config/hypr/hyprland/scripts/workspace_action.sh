#!/usr/bin/env bash
active_workspace="$(hyprctl activeworkspace -j)"
curr_workspace="$(echo "$active_workspace" | jq -r ".id")"

curr_monitor_id="$(echo "$active_workspace" | jq -r ".monitorID")"
curr_special_workspace="$(hyprctl monitors -j | jq -r ".[$curr_monitor_id].specialWorkspace.name")"

dispatcher="$1"
shift ## The target is now in $1, not $2

if [[ "$dispatcher" == "openspecialworkspace" || "$dispatcher" == "openspecialworkspaceifnotempty" ]]; then
  if [[ "$curr_special_workspace" != "special:${1:-"special"}" ]]; then
    if [[ "$dispatcher" == "openspecialworkspaceifnotempty" ]]; then
      numWindows="$(hyprctl workspaces -j | jq '.[] | select(.name == "special:'${1:-"special"}'").windows')"
      if (( numWindows == 0 )); then
        exit
      fi
    fi
  
    hyprctl dispatch togglespecialworkspace $1
  fi
  exit
elif [[ "$dispatcher" == "closespecialworkspace" ]]; then
  if [[ "$curr_special_workspace" == "special:${1:-"special"}" ]]; then
    hyprctl dispatch togglespecialworkspace $1
  fi
  exit
fi

if [[ -z "${dispatcher}" || "${dispatcher}" == "--help" || "${dispatcher}" == "-h" || -z "$1" ]]; then
  echo "Usage: $0 <dispatcher> <target>"
  exit 1
fi
if [[ "$1" == *"+"* || "$1" == *"-"* ]]; then ## Is this something like r+1 or -1?
  hyprctl dispatch "${dispatcher}" "$1" ## $1 = workspace id since we shifted earlier.
elif [[ "$1" =~ ^[0-9]+$ ]]; then ## Is this just a number?
  target_workspace=$((((curr_workspace - 1) / 10 ) * 10 + $1))
  hyprctl dispatch "${dispatcher}" "${target_workspace}"
else
  hyprctl dispatch "${dispatcher}" "$1" ## In case the target in a string, required for special workspaces.
  exit 1
fi
