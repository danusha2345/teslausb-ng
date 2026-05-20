---
name: run
description: "Skill for the Run area of teslausb-ng. 41 symbols across 2 files."
---

# Run

41 symbols | 2 files | Cohesion: 86%

## When to Use

- Working with code in `run/`
- Understanding how list_vehicles, get_vehicle_online_state, is_vehicle_online work
- Modifying run-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `run/tesla_api.py` | _invalidate_access_token, _rest_request, _get_api_token, _get_id, _load_tesla_api_json (+34) |
| `run/filter_savedclips_window.py` | parse_clip_ts, main |

## Entry Points

Start here when exploring this area:

- **`list_vehicles`** (Function) — `run/tesla_api.py:280`
- **`get_vehicle_online_state`** (Function) — `run/tesla_api.py:314`
- **`is_vehicle_online`** (Function) — `run/tesla_api.py:323`
- **`streaming_ping`** (Function) — `run/tesla_api.py:379`
- **`wake_up_vehicle`** (Function) — `run/tesla_api.py:406`

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `list_vehicles` | Function | `run/tesla_api.py` | 280 |
| `get_vehicle_online_state` | Function | `run/tesla_api.py` | 314 |
| `is_vehicle_online` | Function | `run/tesla_api.py` | 323 |
| `streaming_ping` | Function | `run/tesla_api.py` | 379 |
| `wake_up_vehicle` | Function | `run/tesla_api.py` | 406 |
| `main` | Function | `run/tesla_api.py` | 541 |
| `get_service_data` | Function | `run/tesla_api.py` | 284 |
| `get_vehicle_summary` | Function | `run/tesla_api.py` | 290 |
| `get_vehicle_legacy_data` | Function | `run/tesla_api.py` | 296 |
| `get_nearby_charging` | Function | `run/tesla_api.py` | 302 |
| `get_vehicle_data` | Function | `run/tesla_api.py` | 308 |
| `get_charge_state` | Function | `run/tesla_api.py` | 327 |
| `get_climate_state` | Function | `run/tesla_api.py` | 333 |
| `get_drive_state` | Function | `run/tesla_api.py` | 339 |
| `get_gui_settings` | Function | `run/tesla_api.py` | 345 |
| `set_charge_limit` | Function | `run/tesla_api.py` | 410 |
| `actuate_trunk` | Function | `run/tesla_api.py` | 417 |
| `actuate_frunk` | Function | `run/tesla_api.py` | 425 |
| `flash_lights` | Function | `run/tesla_api.py` | 433 |
| `get_vehicle_state` | Function | `run/tesla_api.py` | 351 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `Main → _get_log_timestamp` | cross_community | 8 |
| `Streaming_ping → _get_log_timestamp` | cross_community | 7 |
| `Toggle_sentry_mode → _get_log_timestamp` | cross_community | 7 |
| `Get_service_data → _get_log_timestamp` | cross_community | 7 |
| `Main → _get_api_functions` | intra_community | 3 |

## How to Explore

1. `gitnexus_context({name: "list_vehicles"})` — see callers and callees
2. `gitnexus_query({query: "run"})` — find related execution flows
3. Read key files listed above for implementation details
