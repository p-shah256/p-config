#!/bin/sh

# This script renames all tabs sequentially (Tab #1, Tab #2, etc.)
# and returns focus to the tab that was active when the script was run.

zellij action rename-tab "__CURRENT__" >/dev/null 2>&1
TABS=$(zellij action query-tab-names)

i=1
CURRENT_INDEX=0

while IFS= read -r TAB; do
    if [ "$TAB" == "__CURRENT__" ]; then
        CURRENT_INDEX=$i
    fi
    zellij action rename-tab "$i"
    zellij action go-to-next-tab

    i=$((i + 1))
done <<< "$TABS"

zellij action go-to-tab $CURRENT_INDEX

