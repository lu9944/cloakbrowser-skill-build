---
name: cloakbrowser
description: Stealth Chromium browser automation that bypasses bot detection. Use this skill whenever the user wants to scrape, screenshot, PDF, or automate a site that blocks normal headless browsers — Cloudflare Turnstile, reCAPTCHA v3, FingerprintJS, ShieldSquare, BrowserScan, "Access Denied" responses, suspicious 403/429s on plain `curl`, or any site where Playwright/Puppeteer get caught. Also use when the user mentions CloakBrowser, stealth Chromium, anti-bot bypass, "headless detection", "real Chrome fingerprint", or wants a one-off "what does this page actually render" check. Prefer this skill over raw `curl`/`fetch` for any site behind a CDN or bot-detection layer.
homepage: https://github.com/CloakHQ/CloakBrowser
---

# CloakBrowser

A patched-source Chromium plus a Playwright-shaped Python wrapper. Fingerprints
are modified at the C++ level (canvas, WebGL, audio, fonts, WebRTC, TLS, CDP
input, `navigator.webdriver`, plugin list, `window.chrome`, …) so detection
services see a real browser because it **is** a real browser — no JS shim that
breaks on the next Chrome upgrade.

## Self-contained — no external setup needed

The Chromium binary and Python runtime are bundled inside this skill directory
under `.chromium/` and `.runtime/`. Scripts automatically discover them via
`scripts/_runtime.py`, which sets `CLOAKBROWSER_BINARY_PATH` and adds the bundled
packages to `sys.path`. No `/usr/local/bin` wrapper or separate install step is
required.

## Decision tree — pick the right tool

| Task                                                          | Use                            |
|---------------------------------------------------------------|--------------------------------|
| Get the HTML or visible text of a page                        | `scripts/fetch.py`             |
| Save a PNG of a page or element                               | `scripts/screenshot.py`        |
| Render a page to PDF                                          | `scripts/pdf.py`               |
| Run a JS expression against a page and get JSON back          | `scripts/eval-js.py`           |
| Confirm stealth is working                                    | `scripts/check-stealth.py`     |
| Long-lived browser shared across many tool calls / skills     | `scripts/serve.sh` + CDP       |
| Multi-step interactive flow (login, click, type, conditional) | Inline Python — see below      |

Always reach for a bundled script first. They use `argparse`, take `--humanize`,
`--proxy`, `--geoip`, `--wait`, etc. — most needs are covered.

## Bundled scripts

All scripts use `#!/usr/bin/env python3` and import `_runtime` to bootstrap the
bundled packages and Chromium path. The skill directory path is shown at the top
of this message (the directory containing this SKILL.md).

**Always use `python3` to run scripts (not `./script.py`)** — zip extraction
may lose execute permissions. For example, if the skill directory is
`/home/ubuntu/.qwenpaw/workspaces/default/skills/cloakbrowser`, run:

```bash
# Replace SKILL_DIR with the actual skill directory path shown above
python3 SKILL_DIR/scripts/fetch.py https://example.com                       # full HTML on stdout
python3 SKILL_DIR/scripts/fetch.py https://example.com --text                # visible text only
python3 SKILL_DIR/scripts/fetch.py https://example.com --selector "h1"       # scoped to a selector
python3 SKILL_DIR/scripts/fetch.py https://protected.example --humanize      # behavioural stealth
python3 SKILL_DIR/scripts/fetch.py https://geo.example --proxy socks5://u:p@host:1080 --geoip

python3 SKILL_DIR/scripts/screenshot.py https://example.com /tmp/out.png --full
python3 SKILL_DIR/scripts/screenshot.py https://example.com /tmp/hero.png --selector ".hero"
python3 SKILL_DIR/scripts/screenshot.py https://example.com /tmp/m.png --viewport 390x844

python3 SKILL_DIR/scripts/pdf.py https://example.com /tmp/page.pdf --format A4
python3 SKILL_DIR/scripts/pdf.py https://example.com /tmp/wide.pdf --landscape

python3 SKILL_DIR/scripts/eval-js.py https://news.example "Array.from(document.querySelectorAll('h2')).map(h=>h.innerText)"
python3 SKILL_DIR/scripts/eval-js.py https://example.com  "({ua: navigator.userAgent, w: innerWidth})"

python3 SKILL_DIR/scripts/check-stealth.py        # JSON report + exit 0 if all 4 stealth tells pass

bash SKILL_DIR/scripts/serve.sh --port 9222       # starts cloakserve in background; logs /tmp/cloakserve.log
```

The pattern is consistent: positional `URL` (and `OUTPUT` where relevant), then
optional flags `--humanize`, `--proxy`, `--geoip`, `--wait`, `--timeout`.

> **Note on `--wait`**: it accepts a page load state name, NOT a number of
> seconds. Valid values: `domcontentloaded` (default), `load`, `networkidle`,
> `commit`. To control time, use `--timeout` (milliseconds, default 30000).

## Inline Python — for everything the scripts don't cover

For multi-step flows (login, fill a form, click through, conditional waits),
write a one-off Python script file in SKILL_DIR/scripts/ so it can import
`_runtime` for the bootstrap:

```bash
cat > SKILL_DIR/scripts/_temp_flow.py <<'PY'
import _runtime  # noqa: F401
from cloakbrowser import launch
b = launch(headless=True, humanize=True)
p = b.new_page()
p.goto("https://example.com/login", wait_until="domcontentloaded")
p.fill("#email", "me@example.com")
p.fill("#password", "…")
p.click("button[type=submit]")
p.wait_for_url("**/dashboard**")
print(p.title())
b.close()
PY
SKILL_DIR/scripts/_temp_flow.py
rm SKILL_DIR/scripts/_temp_flow.py
```

The API is identical to Playwright's sync API — anything in the Playwright
docs works here. The only differences:

- `from cloakbrowser import launch` (not `from playwright.sync_api`)
- Skip `sync_playwright().start()` — `launch()` is a top-level function
- All stealth flags (`humanize`, `proxy`, `geoip`, `auto_update`) go on
  `launch()`, not the page

For persistent sessions, use `launch_persistent_context(user_data_dir)`.

## When to load `references/stealth-knobs.md`

Read it when:

- A target blocks despite stealth (covers `humanize` / proxy / persistent
  profile escalation order).
- The user asks about proxies, residential vs datacentre, geo matching.
- You need to share one browser across many tool calls (CDP server mode).

For routine "fetch this URL" / "screenshot this page" work, the table and
script examples above are enough — don't load the reference.

## Anti-patterns

- Don't run `playwright install` — CloakBrowser ships its own Chromium and
  doesn't use Playwright's bundled binaries.
- Don't enable `humanize=True` for plain scraping of unprotected sites — it
  adds latency with no win.
- Don't keep `serve.sh` running for a one-shot fetch. The CDP server is for
  shared, long-lived sessions; `fetch.py` is faster for one URL.

## Troubleshooting

- `Binary not found` → the Chromium binary should be at `.chromium/` inside
  this skill directory. If missing, re-import the full skill zip.
- `ModuleNotFoundError: cloakbrowser` → `scripts/_runtime.py` failed to add
  `.runtime/lib` to `sys.path`. Check that `.runtime/lib/` exists inside this
  skill directory.
- Slow startup / hang on launch → `CLOAKBROWSER_AUTO_UPDATE=0` is already set
  by `_runtime.py`. If it still hangs, the binary may be corrupted; re-import
  the skill zip.
- Still blocked → see `references/stealth-knobs.md` for the escalation order
  (`humanize` → residential proxy + `geoip` → persistent profile).
