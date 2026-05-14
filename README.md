# cloakbrowser-skill

A [Claude](https://claude.com/claude-code) skill that wraps
[CloakBrowser](https://github.com/CloakHQ/CloakBrowser) — stealth Chromium that
passes most bot-detection layers (Cloudflare Turnstile, reCAPTCHA v3,
FingerprintJS, ShieldSquare, BrowserScan, generic 403/429 walls).

Drop it into your Claude skills folder and your agent can fetch, screenshot,
PDF, or run JavaScript against sites that block normal headless browsers — no
hand-rolled Playwright code per task.

## What's in here

```
cloakbrowser/
├── SKILL.md                              # frontmatter + agent instructions
├── scripts/
│   ├── fetch.py                          # HTML or visible text, optional CSS selector
│   ├── screenshot.py                     # PNG (full page, element, or custom viewport)
│   ├── pdf.py                            # render page → PDF
│   ├── eval-js.py                        # run a JS expression, get JSON
│   ├── check-stealth.py                  # confirm stealth fingerprint passes 4 core tells
│   ├── serve.py + serve.sh               # long-lived CDP endpoint for shared sessions
└── references/
    └── stealth-knobs.md                  # when to use humanize / proxies / geoip / profiles
```

The agent reads `SKILL.md`, picks the right script for the task, shells out.
No heredoc Python per call.

## Install

### One-time prereqs

CloakBrowser ships its stealth Chromium binary out-of-band, so you install it
once on the host:

```bash
uv tool install cloakbrowser     # or `pipx install cloakbrowser` on a non-PEP-668 system
cloakbrowser install             # downloads the ~206 MB patched Chromium
```

This gives you:

- `cloakbrowser` CLI at `~/.local/bin/cloakbrowser`
- wrapper Python at `~/.local/share/uv/tools/cloakbrowser/bin/python`
- stealth Chromium at `~/.cloakbrowser/chromium-<version>/chrome`

### Drop the skill into Claude

Clone (or copy) this repo into the skill folder Claude reads. For Claude Code:

```bash
git clone https://github.com/OctavianTocan/cloakbrowser-skill.git \
  ~/.claude/skills/cloakbrowser
```

For other Claude harnesses, drop the `cloakbrowser/` directory wherever your
harness loads skills from.

### Heads up on the shebang

Every script in `scripts/` has an absolute shebang pointing at
`/root/.local/share/uv/tools/cloakbrowser/bin/python` (the path `uv tool
install` produced on the system this skill was authored on). If your install
path differs, either:

- run `sed -i "s|/root/.local/share/uv/tools/cloakbrowser/bin/python|$(uv tool dir)/cloakbrowser/bin/python|" scripts/*.py`, or
- invoke the scripts via the venv explicitly:
  `"$(uv tool dir)/cloakbrowser/bin/python" scripts/fetch.py URL`.

## Usage at a glance

Once installed, the agent uses the scripts directly:

```bash
SK=~/.claude/skills/cloakbrowser/scripts

$SK/fetch.py https://example.com                       # full HTML
$SK/fetch.py https://example.com --text --selector h1  # scoped text
$SK/screenshot.py https://example.com out.png --full
$SK/pdf.py https://example.com out.pdf --landscape
$SK/eval-js.py https://news.example "Array.from(document.querySelectorAll('h2')).map(h=>h.innerText)"
$SK/check-stealth.py                                   # exit 0 if stealth passes
$SK/serve.sh --port 9222                               # long-lived CDP for shared sessions
```

All scripts take `--humanize`, `--proxy URL`, `--geoip`, `--wait STATE`,
`--timeout MS` where they make sense. See `references/stealth-knobs.md` for the
escalation order when a site still blocks.

For multi-step interactive flows (login, click, conditional waits) the agent
writes inline Python against the Playwright-shaped API — see "Inline Python"
in `SKILL.md`.

## Why a skill rather than just `pip install cloakbrowser`?

CloakBrowser is a library, not a CLI. Without this skill, every agent run
reinvents the same Playwright boilerplate as a heredoc. The skill gives the
agent:

- A consistent decision tree (which script for which intent).
- Pre-built scripts with `argparse` for `--humanize`, `--proxy`, `--geoip`,
  `--selector`, `--viewport`, `--full`, `--landscape`.
- Progressive disclosure: stealth tuning lives in `references/`, loaded only
  when an agent actually needs to escalate past blocks.
- A self-check (`check-stealth.py`) the agent can run to verify the install
  before committing to a hard run.

## Verified

Smoke-tested end-to-end on Debian 12 (Linux 6.8) against `example.com`:

| Script | Verification |
|---|---|
| `check-stealth.py` | all 4 stealth tells pass (webdriver false, plugins>0, window.chrome=object, UA ≠ HeadlessChrome) |
| `fetch.py` | full HTML, `--text`, `--selector h1` all return correct content |
| `screenshot.py` | `--full`, `--viewport 390x844`, `--selector h1` produce valid PNGs |
| `pdf.py` | default + `--landscape` produce valid `%PDF-` files |
| `eval-js.py` | arbitrary JSON-returning expressions evaluate |
| `serve.sh` | CDP up at `/json/version`, advertises `Chrome/146.0.7680.177`, clean SIGTERM shutdown |

`--humanize`, `--proxy`, `--geoip` codepaths exercised but not end-to-end
verified against a real protected target — bring your own bot-protected URL +
residential proxy for a behavioural smoke test.

## License

MIT — see [LICENSE](LICENSE). CloakBrowser itself is separately licensed by
CloakHQ; see [their repo](https://github.com/CloakHQ/CloakBrowser) for terms
on the binary and source patches.

## Acknowledgements

Built on [CloakHQ/CloakBrowser](https://github.com/CloakHQ/CloakBrowser). This
skill is just an agent-ergonomics wrapper around it.
