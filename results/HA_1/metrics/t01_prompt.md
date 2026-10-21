You're the analytics engineer for a Formula 1 analytics team. This directory is empty except for `profiles.yml` (profile `f1`, target `dev`) — build us a production-quality dbt project from scratch.

**Warehouse:** Snowflake. Raw data is in `ANALYTICS_DEV.F1_RAW_HA_1` — 14 tables loaded straight from the Ergast/Kaggle F1 CSVs (1950 to the current season). Everything was loaded as text, exactly as it appeared in the files. Treat that schema as read-only. Your models must build into `F1_DBT_HA_1` (custom schema suffixes are fine). Don't touch any other schema. `dbt` is installed and on your PATH.

**We need these four models, with these exact names and at least these columns:**

1. `fct_results`: one row per race result entry (Grand Prix results only, not sprints).
   `result_id, race_id, season, round, race_date, driver_id, constructor_id, constructor_name, grid, finish_position (null when not classified), position_order, points, laps, status, is_win, is_podium, fastest_lap_time_ms` (the fastest lap as integer milliseconds).
2. `dim_drivers`: one row per driver.
   `driver_id, driver_ref, full_name, nationality, date_of_birth, career_starts (distinct Grands Prix entered), career_wins, career_podiums, world_championships`.
   A championship only counts once that season is complete: every race on that season's calendar has results.
3. `mart_driver_season_standings`: one row per driver per season, as of the latest completed round.
   `season, driver_id, championship_position, points, wins`. This must match the *official* championship standings, so check your numbers against real history.
4. `mart_constructor_season_pit_stops`: one row per constructor per season with pit stop data.
   `season, constructor_id, pit_stop_count, median_pit_stop_seconds`. Exclude stops over 60 seconds (red-flag stoppages, not real stops).

Organize the project the way you'd want to maintain it for years. Include sources, tests, and documentation as you see fit. When you're done, `dbt build` must succeed. Finish with a short summary of what you built and any data quirks you found.
