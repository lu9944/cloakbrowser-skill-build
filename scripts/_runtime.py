import os
import sys
from pathlib import Path

_SKILL_DIR = Path(__file__).resolve().parent.parent
_RUNTIME_LIB = _SKILL_DIR / ".runtime" / "lib"
_CHROMIUM_DIR = _SKILL_DIR / ".chromium"

if _RUNTIME_LIB.is_dir():
    sys.path.insert(0, str(_RUNTIME_LIB))

_chrome = next(_CHROMIUM_DIR.glob("chromium-*/chrome"), None)
if _chrome and _chrome.is_file():
    os.environ["CLOAKBROWSER_BINARY_PATH"] = str(_chrome)
else:
    os.environ.setdefault("CLOAKBROWSER_CACHE_DIR", str(_CHROMIUM_DIR))

os.environ["CLOAKBROWSER_AUTO_UPDATE"] = "0"
