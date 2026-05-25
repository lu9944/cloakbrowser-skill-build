#!/usr/bin/env bash
# All-in-one offline installer (backward compatible).
#
# For the recommended two-package approach, use:
#   sudo install-runtime.sh        # one-time runtime setup
#   + import cloakbrowser-skill.zip via QwenPaw
#
# This script combines both steps for convenience.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

# --- If this is a runtime-only tarball, just run the runtime installer ---
if [[ -f "$SCRIPT_DIR/install-runtime.sh" ]]; then
  say "Detected runtime package layout. Running install-runtime.sh..."
  exec "$SCRIPT_DIR/install-runtime.sh" "$@"
fi

# --- Otherwise, fall back to the all-in-one layout ---
RUNTIME_DIR="$SCRIPT_DIR/runtime"
SKILL_SRC="$SCRIPT_DIR/skill"

if [[ ! -d "$RUNTIME_DIR" ]] && [[ ! -d "$SKILL_SRC" ]]; then
  echo "Error: Not a valid offline package." >&2
  echo "  Expected: runtime/ + skill/ directories, or install-runtime.sh" >&2
  echo "" >&2
  echo "For the recommended approach, use:" >&2
  echo "  1. tar -xzf cloakbrowser-runtime-x86_64-linux.tar.gz && sudo ./install-runtime.sh" >&2
  echo "  2. Import cloakbrowser-skill.zip into QwenPaw" >&2
  exit 1
fi

# Delegate to install-runtime.sh if runtime directory exists
if [[ -d "$RUNTIME_DIR" ]] && [[ -f "$SCRIPT_DIR/install-runtime.sh" ]]; then
  say "Running runtime installer..."
  "$SCRIPT_DIR/install-runtime.sh"
  echo ""
fi

# Import skill into QwenPaw if skill directory exists
if [[ -d "$SKILL_SRC" ]] && [[ -f "$SKILL_SRC/SKILL.md" ]]; then
  say "Skill files detected at $SKILL_SRC"
  say "To import into QwenPaw, use the zip upload in the web UI or:"
  say "  POST /skills/upload with cloakbrowser-skill.zip"
fi

say "Done."
