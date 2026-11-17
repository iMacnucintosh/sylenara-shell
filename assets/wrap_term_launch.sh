#!/usr/bin/env sh

cat ~/.local/state/lunele/sequences.txt 2>/dev/null

exec "$@"
