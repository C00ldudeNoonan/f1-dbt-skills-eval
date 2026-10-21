The performance team has started receiving car telemetry: `CAR_TELEMETRY` in the raw schema, about 20 million rows from 2022 onward (roughly 4 samples per second per car). Each row has `_LOADED_AT`, the time it landed in our warehouse. Samples can arrive late, sometimes weeks after the race.

1. `fct_telemetry`: one row per sample, with `race_id, driver_id, lap, sample_index, recorded_at, speed_kph, throttle_pct, brake, gear, drs`.
2. `mart_lap_telemetry_summary`: one row per driver per lap, with `race_id, driver_id, lap, samples, max_speed_kph, avg_throttle_pct, full_throttle_pct` (share of samples with throttle at 99 or above, as a percentage), and `brake_samples`.

Warehouse cost matters now. Routine runs must not rescan the whole raw telemetry table. They must pick up late samples correctly, and the summary must stay correct without full refreshes. Explain your design and roughly what a routine run costs compared with a full rebuild. Make sure `dbt build` succeeds when you're done.
