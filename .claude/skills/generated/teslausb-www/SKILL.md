---
name: teslausb-www
description: "Skill for the Teslausb-www area of teslausb-ng. 9 symbols across 1 files."
---

# Teslausb-www

9 symbols | 1 files | Cohesion: 100%

## When to Use

- Working with code in `teslausb-www/`
- Understanding how FOURCC work
- Modifying teslausb-www-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `teslausb-www/cttseraser.cpp` | FOURCC, get_chunk, parse_chunks, find_ctts, do_open (+4) |

## Entry Points

Start here when exploring this area:

- **`FOURCC`** (Function) — `teslausb-www/cttseraser.cpp:175`

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `FOURCC` | Function | `teslausb-www/cttseraser.cpp` | 175 |
| `get_chunk` | Function | `teslausb-www/cttseraser.cpp` | 189 |
| `parse_chunks` | Function | `teslausb-www/cttseraser.cpp` | 210 |
| `find_ctts` | Function | `teslausb-www/cttseraser.cpp` | 245 |
| `do_open` | Function | `teslausb-www/cttseraser.cpp` | 259 |
| `convert_timestamp` | Function | `teslausb-www/cttseraser.cpp` | 57 |
| `statx2stat` | Function | `teslausb-www/cttseraser.cpp` | 66 |
| `mystat` | Function | `teslausb-www/cttseraser.cpp` | 119 |
| `do_getattr` | Function | `teslausb-www/cttseraser.cpp` | 145 |

## How to Explore

1. `gitnexus_context({name: "FOURCC"})` — see callers and callees
2. `gitnexus_query({query: "teslausb-www"})` — find related execution flows
3. Read key files listed above for implementation details
