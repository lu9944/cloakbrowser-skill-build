#!/usr/bin/env bash
# One-time runtime installer for cloakbrowser skill.
# Run this ONCE per machine (needs sudo). After this, import cloakbrowser-skill.zip
# into QwenPaw via the web UI or API and the skill works immediately.
#
# Usage:
#   tar -xzf cloakbrowser-runtime-x86_64-linux.tar.gz
#   sudo ./install-runtime.sh
#
# What it does:
#   1. Deploys Python venv to /opt/cloakbrowser/
#   2. Deploys Chromium binary to ~/.cloakbrowser/
#   3. Creates /usr/local/bin/cloakbrowser-python wrapper
#   4. Creates /usr/local/bin/cloakbrowser CLI symlink
#
# After running this, import cloakbrowser-skill.zip into QwenPaw.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_SRC="$SCRIPT_DIR/venv"
CB_DATA_SRC="$SCRIPT_DIR/cloakbrowser-data"

VENV_DEST="/opt/cloakbrowser"
WRAPPER="/usr/local/bin/cloakbrowser-python"
CB_BIN="/usr/local/bin/cloakbrowser"

say()   { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

if [[ "$(id -u)" -ne 0 ]]; then
  die "Need root. Run with: sudo ./install-runtime.sh"
fi

# --- Validate package contents ---
if [[ ! -d "$VENV_SRC" ]]; then
  die "venv/ not found. Did you extract the runtime tarball?"
fi
if [[ ! -d "$CB_DATA_SRC" ]]; then
  die "cloakbrowser-data/ not found. Did you extract the runtime tarball?"
fi

# --- Determine real user (for ownership) ---
REAL_HOME="${SUDO_USER_HOME:-$HOME}"
if [[ -n "${SUDO_USER:-}" ]]; then
  REAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
fi

# --- 1. Deploy venv ---
if [[ -d "$VENV_DEST" ]]; then
  say "Removing existing venv at $VENV_DEST"
  rm -rf "$VENV_DEST"
fi
say "Deploying Python venv -> $VENV_DEST"
cp -a "$VENV_SRC" "$VENV_DEST"

# --- 2. Deploy Chromium binary ---
CB_HOME="$REAL_HOME/.cloakbrowser"
if [[ -d "$CB_HOME" ]]; then
  say "Backing up existing $CB_HOME -> $CB_HOME.bak"
  rm -rf "$CB_HOME.bak"
  mv "$CB_HOME" "$CB_HOME.bak"
fi
say "Deploying stealth Chromium -> $CB_HOME"
cp -a "$CB_DATA_SRC" "$CB_HOME"
if [[ -n "${SUDO_USER:-}" ]]; then
  chown -R "$SUDO_USER":"$(id -gn "$SUDO_USER")" "$CB_HOME"
fi

# --- 3. Create wrapper ---
VENV_PY="$VENV_DEST/bin/python"
[[ -x "$VENV_PY" ]] || die "Python not found at $VENV_PY"

say "Creating wrapper $WRAPPER"
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
exec $VENV_PY "\$@"
EOF
chmod +x "$WRAPPER"

# --- 4. Create CLI symlink ---
CB_CLI="$VENV_DEST/bin/cloakbrowser"
if [[ -x "$CB_CLI" ]]; then
  ln -sf "$CB_CLI" "$CB_BIN"
  say "Linked $CB_BIN -> $CB_CLI"
fi

# --- 5. Verify ---
say "Verifying..."
"$WRAPPER" -c "import cloakbrowser; print('  Python package: OK')"

CHROME="$(find "$CB_HOME" -name "chrome" -type f | head -1 || true)"
if [[ -n "$CHROME" ]]; then
  say "  Chromium: $CHROME ($(du -sh "$CHROME" | cut -f1))"
else
  warn "  Chromium binary not found in $CB_HOME"
fi

say "Runtime installed. Now import cloakbrowser-skill.zip into QwenPaw."
