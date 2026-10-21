New ask: the race engineers want lap-level data.

Add `fct_lap_times`: one row per driver per lap per race, with at least `race_id, season, round, driver_id, lap, position, lap_time_ms`.

This table is large and new races land in the raw tables after every Grand Prix, so it must be **incremental**: don't reprocess history on every run. Be aware that the timing provider sometimes reissues *corrected* lap times for either of the two most recent races already loaded. Those corrections must flow through without a full refresh.

Make sure `dbt build` succeeds when you're done.
