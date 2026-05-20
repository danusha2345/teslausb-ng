---
name: html
description: "Skill for the Html area of teslausb-ng. 86 symbols across 2 files."
---

# Html

86 symbols | 2 files | Cohesion: 78%

## When to Use

- Working with code in `teslausb-www/`
- Understanding how constructor, newFolder, deleteItems work
- Modifying html-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `teslausb-www/html/filebrowser.js` | constructor, newFolder, deleteItems, deleteItem, downloadSelection (+74) |
| `teslausb-www/html/contextmenu.js` | ContextMenuItem, ContextMenu, constructor, show, hide (+2) |

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `ContextMenuItem` | Class | `teslausb-www/html/contextmenu.js` | 0 |
| `ContextMenu` | Class | `teslausb-www/html/contextmenu.js` | 11 |
| `callback` | Function | `teslausb-www/html/filebrowser.js` | 155 |
| `sleep` | Function | `teslausb-www/html/filebrowser.js` | 972 |
| `resize` | Function | `teslausb-www/html/filebrowser.js` | 489 |
| `cancelSelectionRectangle` | Function | `teslausb-www/html/filebrowser.js` | 524 |
| `pointerup` | Function | `teslausb-www/html/filebrowser.js` | 540 |
| `constructor` | Method | `teslausb-www/html/filebrowser.js` | 13 |
| `newFolder` | Method | `teslausb-www/html/filebrowser.js` | 146 |
| `deleteItems` | Method | `teslausb-www/html/filebrowser.js` | 172 |
| `deleteItem` | Method | `teslausb-www/html/filebrowser.js` | 188 |
| `downloadSelection` | Method | `teslausb-www/html/filebrowser.js` | 192 |
| `selectItemContent` | Method | `teslausb-www/html/filebrowser.js` | 207 |
| `applyRename` | Method | `teslausb-www/html/filebrowser.js` | 219 |
| `stopEditingItem` | Method | `teslausb-www/html/filebrowser.js` | 234 |
| `renameItem` | Method | `teslausb-www/html/filebrowser.js` | 245 |
| `makeLockChime` | Method | `teslausb-www/html/filebrowser.js` | 267 |
| `eventCoordinates` | Method | `teslausb-www/html/filebrowser.js` | 302 |
| `makeMultiSelectContextMenu` | Method | `teslausb-www/html/filebrowser.js` | 310 |
| `makeListContextMenu` | Method | `teslausb-www/html/filebrowser.js` | 325 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `Drop → DirClicked` | cross_community | 10 |
| `Drop → StringEncode` | cross_community | 9 |
| `Drop → AddCommonDragHooks` | cross_community | 9 |
| `Drop → Readfile` | cross_community | 8 |
| `Callback → DirClicked` | intra_community | 6 |
| `Constructor → Selection` | cross_community | 5 |
| `Constructor → ShowButton` | cross_community | 5 |
| `Constructor → IsPotentialLockChime` | cross_community | 5 |
| `Constructor → StringEncode` | cross_community | 5 |
| `Constructor → Readfile` | intra_community | 5 |

## How to Explore

1. `gitnexus_context({name: "constructor"})` — see callers and callees
2. `gitnexus_query({query: "html"})` — find related execution flows
3. Read key files listed above for implementation details
