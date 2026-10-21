New ask from the race engineers: lap-level data and tyre stints.

1. `fct_lap_times`: one row per driver per lap per race, with at least `race_id, season, round, driver_id, lap, position, lap_time_ms`. It must be **incremental**, because the table is large and new races land after every Grand Prix. The timing provider sometimes reissues *corrected* lap times for either of the two most recent races already loaded, and those corrections must flow through without a full refresh.
2. `fct_stints`: one row per driver per stint, for races that have pit stop data.
   `race_id, driver_id, stint_number, start_lap, end_lap, stint_laps, avg_lap_time_ms`. Stint 1 starts on lap 1. A pit stop on lap L ends the current stint at lap L, and the next stint starts at lap L+1. The final stint ends on the driver's last recorded lap. Drop stints with no laps. `avg_lap_time_ms` averages every lap in the stint. It must stay correct when new races and lap corrections arrive, also without a full refresh.

Make sure `dbt build` succeeds when you're done.
