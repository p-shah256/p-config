#!/bin/bash

# follows unix convention of
# stdout = machine-readable data for piping/processing
# stderr = human-readable messages for monitoring

LOG_COLOR_DEBUG="\033[2;37m" # Dim Light Gray
LOG_COLOR_INFO="\033[0m"     # Default Terminal Color (Reset)
LOG_COLOR_ERROR="\033[1;31m" # Bold Blood Red
LOG_COLOR_RESET="\033[0m"

LOG_LEVEL=${LOG_LEVEL:-0}

log_info() {
	printf "${LOG_COLOR_INFO}%-7s %s - %s${LOG_COLOR_RESET}\n" "[INFO]" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >&2
}

log_debug() {
	if [ "$LOG_LEVEL" -ge 1 ]; then
		printf "${LOG_COLOR_DEBUG}%-7s %s - %s${LOG_COLOR_RESET}\n" "[DEBUG]" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >&2
	fi
}

log_error() {
	printf "${LOG_COLOR_ERROR}%-7s %s - %s${LOG_COLOR_RESET}\n" "[ERROR]" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >&2
}
