#!/bin/sh
# x28link.sh — Link-state reader adapter for AX3000T.
# Delegates to canonical linkstate.sh logic.

HERE="$(dirname "$0")"
if [ -f "$HERE/x28/linkstate.sh" ]; then
    exec sh "$HERE/x28/linkstate.sh" "$@"
elif [ -f "$HERE/linkstate.sh" ]; then
    exec sh "$HERE/linkstate.sh" "$@"
else
    # Direct fallback if linkstate.sh is absent
    . "${X28_LIB:-$HERE/x28lib.sh}"
    x28_linkstate
fi
