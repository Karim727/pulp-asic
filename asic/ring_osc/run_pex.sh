#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PDK_ROOT="${PDK_ROOT:-/home/karim/.ciel/ciel/sky130/versions/8afc8346a57fe1ab7934ba5a6056ea8b43078e71}"
export DESIGN_NAME="${DESIGN_NAME:-ring_osc}"

# Auto-enter LibreLane AppImage devshell if magic is not on PATH
if ! command -v magic >/dev/null 2>&1; then
    DEVSHELL="${LIBRELANE_DEVSHELL:-$HOME/librelane-devshell-x86_64.AppImage}"
    if [[ -x "$DEVSHELL" ]]; then
        export APPIMAGELAUNCHER_DISABLE=true
        exec "$DEVSHELL" "$0" "$@"
    fi
    echo "ERROR: 'magic' not found in PATH and '$DEVSHELL' not executable." >&2
    exit 1
fi

if [[ $# -ge 1 ]]; then
    export GDS_FILE="$(realpath "$1")"
else
    LATEST_GDS="$(ls -dt "$SCRIPT_DIR"/runs/*/final/gds/"${DESIGN_NAME}".gds 2>/dev/null | head -n 1 || true)"
    if [[ -z "$LATEST_GDS" ]]; then
        echo "ERROR: No final GDS found under $SCRIPT_DIR/runs/*/final/gds/${DESIGN_NAME}.gds" >&2
        echo "Usage: $0 [path/to/ring_osc.gds] [out_pex.spice]" >&2
        exit 1
    fi
    export GDS_FILE="$LATEST_GDS"
fi

if [[ $# -ge 2 ]]; then
    export OUT_SPICE="$(realpath -m "$2")"
else
    export OUT_SPICE="$SCRIPT_DIR/${DESIGN_NAME}_pex.spice"
fi

MAGICRC="$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc"
TMP_WORK="$(mktemp -d)"
trap 'rm -rf "$TMP_WORK"' EXIT

cd "$TMP_WORK"
magic -dnull -noconsole -rcfile "$MAGICRC" "$SCRIPT_DIR/extract_pex.tcl"
