# Contributing to teslausb-ng

Thanks for thinking about it. The maintainer of this fork does not own a Tesla
or a Raspberry Pi, so every external contribution — bug reports, hardware
confirmations, code patches — is what keeps this project from drifting the way
upstream `marcone/teslausb` did.

## Three things you can do, ranked by value

### 1. Run it on real hardware and tell us what happened

This is the most valuable contribution. CI gives us about 60% of the signal we
need; the other 40% only exists on a Pi connected to a Tesla. If you run a
tagged release (or `main-dev`), file a report:

- ✅ **It works** → open a [works-for-me issue](https://github.com/danusha2345/teslausb-ng/issues/new?template=works_for_me.yml).
  One sentence describing your setup is enough; the checkbox at the bottom
  enrolls you for pre-release smoke testing if you're up for it.
- ❌ **It breaks** → open a [bug report](https://github.com/danusha2345/teslausb-ng/issues/new?template=bug_report.yml).
  Fill in every field — the commit hash, Pi model, Tesla firmware, archive
  backend, and the `journalctl -u teslausb` slice. Incomplete reports sit
  untriaged because we cannot guess at the missing data.

### 2. Send a code PR

PRs are welcome. Read the rules below before opening one; following them gets
your PR merged faster.

### 3. Help shape the roadmap

Comment on [ROADMAP.md](ROADMAP.md) items in
[Discussions](https://github.com/danusha2345/teslausb-ng/discussions) if you
want priorities shifted, or open an issue describing a feature that isn't on
the list. We do most of the planning in the open.

---

## Before you open a PR

### Pick a scope and stick to it

- One conceptual change per PR. "Fix #1029 + refactor archiveloop" is two PRs.
- Reference the ROADMAP section in the PR title when applicable, e.g.
  `v1.2.2: multi-vehicle support — first slice`.
- For anything sized **(L)** or **(XL)** in the ROADMAP, open an issue first
  to align on scope before writing code.

### Make sure it builds locally

CI checks the following on every push and PR:

| Check | What it runs |
|-------|--------------|
| **ShellCheck** | 3-pass `check.sh` (strict / warning / error-only). Pass-1A and pass-1B must stay green; pass-2 only fails on actual errors. |
| **shfmt** | Advisory — format diff against 2-space indent, `-ci -sr`. CI warns but doesn't fail. |
| **prettier** | Advisory — JS/CSS/HTML formatting. CI warns but doesn't fail. |
| **Playwright smoke** | `tests/webui/smoke.spec.mjs` exercises `FileBrowser.htmlEscape`. New JS that lands behind security-critical paths should grow this test. |
| **Path-traversal unit tests** | `tests/security/path-traversal-test.sh`. New CGI endpoints that take a path argument must source `_validate_path.sh` and add a test case here. |
| **Build Image** (tag pushes only) | `tools/build-image.sh master` — full pi-gen build, ~50 minutes. Auto-attaches the resulting `image_*-teslausb.zip` to the matching GitHub Release. |

Reproduce locally with:

```bash
bash ./check.sh                                  # ShellCheck (apt-get install shellcheck)
bash tests/security/path-traversal-test.sh       # 11 unit tests
cd tests/webui && npm install && npx playwright test --config=playwright.config.mjs
```

### Commit hygiene

- **Conventional commits**: `feat:` / `fix:` / `refactor:` / `docs:` / `ci:` /
  `chore:` / `test:` / `perf:` / `security:`. Subject line ≤ 72 chars, body
  wrapped at 80.
- Each commit message must answer "why". File diffs answer "what" already.
- Avoid back-to-back stats refresh / index touch / typo-fix commits.
  Squash them with `git rebase -i` before opening the PR.
- Cherry-picks from upstream `marcone/teslausb` use the format
  `feat: <description> (cherry-pick #1234)` and credit the original author
  with a `Co-authored-by:` trailer.

### Tool policy

The repo's [CLAUDE.md](CLAUDE.md) documents which intelligence tool (GitNexus,
Serena, graphify) to reach for in which situation. If you're using an
AI-assisted editor, follow that guidance. Highlights:

- **GitNexus first** for cross-language navigation and blast-radius analysis.
- **Serena only** in `run/tesla_api.py` and `run/filter_savedclips_window.py`.
- **Skip graphify** — overkill for this repo.

### Security-sensitive surfaces

These touch every browser-side user, so changes here need extra care:

- `teslausb-www/html/cgi-bin/_validate_path.sh` — sourced by all mutating
  CGI endpoints. New endpoints that take a path argument MUST source it.
- `teslausb-www/html/filebrowser.js:htmlEscape` — every new `innerHTML`
  splice that includes a filename, label, or path MUST run through it.
- `run/_ble_health.sh` — keeps the BLE failure counter consistent across
  callers. Don't bypass `_ble_health_record_success` /
  `_ble_health_record_failure` in new BLE call sites.

---

## When a PR will get rejected, kindly

- **Adds a feature that needs a server we don't operate.** No mandatory cloud
  dependencies. Optional ones with a clear opt-in env var are fine.
- **Removes the `Boosty` link or otherwise touches the funding surface.**
  Send a discussion instead if you have a specific concern.
- **Reformats files we haven't touched.** Style-only diffs across the whole
  repo are noise; we move files into strict pass-1 of `check.sh` as their
  warnings get cleaned in scoped commits.
- **Lacks a "why".** A diff with no explanation in the commit message or PR
  body sits in review until one shows up.

---

## Releases

Tags follow SemVer. The maintainer cuts releases when:

1. ShellCheck + Lint & Format have been green on `main-dev` for at least 24h.
2. At least one external `works-for-me` report exists for the headline change.
3. CHANGELOG.md has the new section drafted.

Tag pushes (`v*`) trigger `Build Image`, which attaches a fresh `.img.xz`
to the release automatically. If a release ships without an image, the
build is still running — pi-gen takes ~50 minutes.

---

## What we won't promise

- A stable internal API. The runtime helpers (`_retry.sh`, `_log.sh`,
  `_ble_health.sh`, `_progress_notifier.sh`, `_telemetry.sh`) may change
  shape between point releases.
- Support for non-Bookworm OSes. Buster and Bullseye are explicitly
  rejected by `setup-teslausb`.
- Long-term security backports. We ship from `main-dev`; if a CVE matters
  to you on an older tag, pin it and patch yourself.

We're a community fork on a budget. The trade-off is shorter time to merge
and a less-cathedral approach to scope.

---

By contributing you agree to license your code under the same MIT terms as
the rest of the repo, and to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).

If `teslausb-ng` has saved you time or made your Tesla life better, consider
supporting via [Boosty](https://boosty.to/danusha/donate) — international
cards accepted.
