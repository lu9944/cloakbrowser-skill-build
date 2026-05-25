import os
import stat
import sys
from pathlib import Path

_SKILL_DIR = Path(__file__).resolve().parent.parent
_RUNTIME_LIB = _SKILL_DIR / ".runtime" / "lib"
_CHROMIUM_DIR = _SKILL_DIR / ".chromium"

if _RUNTIME_LIB.is_dir():
    sys.path.insert(0, str(_RUNTIME_LIB))

_chrome = next(_CHROMIUM_DIR.glob("chromium-*/chrome"), None)
if _chrome and _chrome.is_file():
    if not os.access(_chrome, os.X_OK):
        _chrome.chmod(0o755)
    os.environ["CLOAKBROWSER_BINARY_PATH"] = str(_chrome)
else:
    os.environ.setdefault("CLOAKBROWSER_CACHE_DIR", str(_CHROMIUM_DIR))

os.environ["CLOAKBROWSER_AUTO_UPDATE"] = "0"

_self = Path(__file__).resolve()
if not os.access(_self, os.X_OK):
    _self.chmod(0o755)
    for _p in _self.parent.glob("*.py"):
        if not os.access(_p, os.X_OK):
            _p.chmod(0o755)
    for _p in _self.parent.glob("*.sh"):
        if not os.access(_p, os.X_OK):
            _p.chmod(0o755)
