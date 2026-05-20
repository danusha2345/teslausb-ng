# Project tool policy — when to reach for what

This codebase is **90% bash + a sprinkle of Python + vanilla JS in one big file**.
Language servers don't have much to say about bash, so the tool to reach for first
is **GitNexus** (multi-language symbol graph with execution flows). The auto-
generated GitNexus section below documents the MCP-tool surface; this block adds
project-specific rules layered on top.

## Default: GitNexus

Use it first for:

- Understanding *how* something works — `gitnexus_query({query: "concept"})`.
- Looking up a single symbol — `gitnexus_context({name: "fnOrClass"})`.
- Blast-radius before editing a function/class/method — `gitnexus_impact(...)`.
- Cross-language flow (Python `tesla_api.py` ↔ bash `awake_*` ↔ JS `filebrowser.js`).

GitNexus indexes bash files as nodes/edges too, even though it can't trace
bash function call-chains the way it does for Python/JS. That's still better
than grep for "where is this used?" questions.

## Use Serena only here

Serena is useful only in two places in this repo:

- `run/tesla_api.py` — full Python LSP makes `find_referencing_symbols`,
  `replace_symbol_body`, and `rename_symbol` precise. Worth the extra round-trip
  for any non-trivial refactor of `_log` / `_error` / `_execute_request` / the
  `_get_*` helper family.
- `run/filter_savedclips_window.py` — same reasoning, smaller surface.

For everything else (bash, vanilla JS, HTML, CGI scripts) Serena adds latency
without payoff. Skip it.

## Skip graphify

`graphify` builds general knowledge graphs from heterogeneous inputs (code +
docs + images). This repo is a tight, single-purpose codebase — `graphify`
would just produce a noisier version of what GitNexus already gives us.
The global graphify graph at `/home/danik/graphs/home-index/` doesn't need
this project added.

## Reindex policy

- Reindex with `npx gitnexus analyze . --skip-agents-md` after a feature
  commit lands. The `--skip-agents-md` flag is **required**: the maintainer
  asked specifically not to clutter history with "refresh index stats" commits
  every time the counts in AGENTS.md / CLAUDE.md tick by a few nodes.
- A CI yaml change, a doc edit, or a comment-only commit is NOT a reason to
  reindex. The graph wouldn't change meaningfully.
- The `GitNexus index is stale (last indexed: …)` hook fires after every Bash
  call once the HEAD has moved past the indexed commit. It's informational;
  ignore it between feature commits. Reindex only when you're about to call
  `gitnexus_query` / `gitnexus_context` / `gitnexus_impact` against new code,
  or when you're about to ship a release.

## Sanity checks before edits

- Run `gitnexus_impact` on the symbol you're about to touch and report the
  result to the user before the first edit if the symbol participates in 3+
  execution flows.
- For symbols GitNexus marks as crossing community boundaries (multi-cluster
  flows), assume HIGH blast radius and explain the plan before editing.
- After a feature commit, run `gitnexus_detect_changes` to confirm only the
  intended symbols moved.

## Repo-specific hotspots worth remembering

From the latest index (762 nodes, 1402 edges, 24 clusters, 34 flows):

- **`run/tesla_api.py:_get_log_timestamp`** participates in 8 cross-community
  flows. Highest fan-in helper in the repo. Migrating it to journald via
  `run/_log.sh` (Python wrapper) gives outsized log-consistency payoff for a
  6-line function.
- **`teslausb-www/html/filebrowser.js:FileBrowser`** has 29+ methods. The
  next ES-module split (v1.1.2 follow-up) should slice by responsibility:
  `FileBrowser.context` (menus), `FileBrowser.splitter` (pointer events),
  `FileBrowser.ops` (file mutations), `FileBrowser.dragdrop` (drop pipeline).
- **`teslausb-www/html/cgi-bin/_validate_path.sh`** is sourced by 8 CGI
  scripts. Treat as HIGH risk for any change — every browser-side mutation
  passes through it.
- **`run/_retry.sh` / `run/_ble_health.sh` / `run/_log.sh` / `run/_progress_notifier.sh`**
  are bash helpers GitNexus tracks as files but can't trace dataflow into.
  For impact analysis on these, grep callers manually with
  `grep -rn "_retry.sh\|retry_with_backoff" run/ teslausb-www/`.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **teslausb-ng** (718 symbols, 1359 relationships, 40 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/teslausb-ng/context` | Codebase overview, check index freshness |
| `gitnexus://repo/teslausb-ng/clusters` | All functional areas |
| `gitnexus://repo/teslausb-ng/processes` | All execution flows |
| `gitnexus://repo/teslausb-ng/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
