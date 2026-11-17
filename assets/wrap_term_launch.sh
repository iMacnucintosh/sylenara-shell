#!/usr/bin/env sh

cat ~/.local/state/sylenara/sequences.txt 2>/dev/null

exec "$@"
