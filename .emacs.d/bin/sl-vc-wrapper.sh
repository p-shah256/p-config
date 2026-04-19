#!/usr/bin/env bash
# Wrapper around sl for Emacs vc-hg compatibility.
# Translates/stubs commands that sl doesn't support.
case "$1" in
  branches)
    # sl has no branches command; return empty output
    ;;
  *)
    exec sl "$@"
    ;;
esac
