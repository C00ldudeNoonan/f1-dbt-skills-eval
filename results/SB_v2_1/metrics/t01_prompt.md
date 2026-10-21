You're the analytics engineer for a Formula 1 analytics team. This directory has only a `profiles.yml` (profile `f1`, target `dev`) and some local config. Build us a production-quality dbt project from scratch. It will grow for years and other teams will depend on it, so design it that way.

**Warehouse:** Snowflake. Raw data is in `ANALYTICS_DEV.F1_RAW_SB_v2_1`: 14 tables loaded straight from the Ergast/Kaggle F1 CSVs (1950 to the current season). Everything was loaded as text, exactly as it appeared in the files. Treat that schema as read-only. Your models must build into `F1_DBT_SB_v2_1` (custom schema suffixes are fine). Don't touch any other schema. `dbt` is installed and on your PATH.

**We need these seven models, with these exact names and at least these columns.** Definitions are precise because downstream teams reconcile against them.

1. `fct_results`: one row per Grand Prix result entry (not sprints).
   `result_id, race_id, season, round, race_date, driver_id, constructor_id, constructor_name, grid, finish_position (null when not classified), position_order, points, laps, status, is_win, is_podium, fastest_lap_time_ms` (integer milliseconds).
2. `dim_drivers`: one row per driver.
   `driver_id, driver_ref, full_name, nationality, date_of_birth, career_starts (distinct Grands Prix entered), career_wins, career_podiums, world_championships`.
   A championship only counts once that season is complete: every race on that season's calendar has results.
3. `mart_driver_season_standings`: one row per driver per season, as of the latest completed round.
   `season, driver_id, championship_position, points, wins`. This must match the *official* championship standings, so check your numbers against real history.
4. `mart_constructor_season_pit_stops`: one row per constructor per season with pit stop data.
   `season, constructor_id, pit_stop_count, median_pit_stop_seconds`. Exclude stops over 60 seconds (red-flag stoppages).
5. `fct_qualifying`: one row per qualifying entry.
   `qualify_id, race_id, driver_id, constructor_id, q1_ms, q2_ms, q3_ms, best_time_ms` (fastest of the three), `gap_to_pole_ms` (best_time_ms minus the fastest best_time_ms in that race), `gap_to_pole_pct` (that gap as a percentage of the pole time, for example 0.512). Times are null when the driver didn't set one.
6. `mart_teammate_head_to_head`: one row per season, constructor, driver and teammate (both orderings), for drivers who raced for the same constructor in the same Grand Prix at least once.
   `season, constructor_id, driver_id, teammate_id, races_together` (distinct Grands Prix where both had a result for that constructor), `races_ahead` (of those, races where the driver's best `position_order` beat the teammate's best), `qualifying_together` (distinct races where both have a qualifying entry for that constructor), `qualifying_ahead` (of those, races where the driver's qualifying position beat the teammate's).
7. `fct_driver_race_pace`: one row per driver per race that has lap data and at least one green-flag lap.
   `race_id, driver_id, green_laps, median_green_lap_ms`. A green-flag lap is any lap *except*: lap 1, a lap on which the driver made a pit stop, the lap immediately after a pit stop, and any lap slower than 130% of the fastest lap anyone set in that race.

Include sources, tests, and documentation as you see fit. When you're done, `dbt build` must succeed. Finish with a short summary of what you built, the design decisions you made, and any data quirks you found.
