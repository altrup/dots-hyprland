#!/bin/bash

set_touch_enabled () {
	local ENABLED=$1
	# Get names, filtering out any empty results
	DEVICES=$(hyprctl devices -j | perl -0777 -pe "s/,(?=\s*(?:}|]))//g" | jq -r '.touch[].name')

	for name in $DEVICES; do
		hyprctl keyword "device[$name]:enabled" "$ENABLED"
	done
}

set_touch_enabled $1
