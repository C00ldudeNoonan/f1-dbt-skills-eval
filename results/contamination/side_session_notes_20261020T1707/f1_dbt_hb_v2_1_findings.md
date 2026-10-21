# F1 HB_v2_1 data findings (verified against ANALYTICS_DEV.F1_RAW_HB_V2_1)

Project: ~/f1-eval-workspaces/HB_v2_1/project. `dbt build` passes: 20 models, 135 tests, 1 seed, 2 unit tests.

This raw copy is not identical to HA_1 or HC_1. Row counts differ: RESULTS 26,719 (HA/HC: 26,739), LAP_TIMES 587,109 (588,048), PIT_STOPS 11,283 (11,343), QUALIFYING 10,454 (10,474), DRIVER_STANDINGS 34,816 (34,839). Re-verify rather than reusing the other notes' numbers.

- `\N` is the null sentinel in every raw table.
- All columns are text. `RACES.round` sorts lexically: `max(round)` returns "9" for every season. Cast before ordering.
- Snowflake `TRY_TO_NUMBER('26.021')` returns 26 (scale 0). Use `try_cast(... as float)` or `as integer`. `TRY_TO_NUMBER('E')` returns 0.
- `LAP_TIMES.MILLISECONDS` is the lap duration (lap 1 ~ 100 s). It is not cumulative race time. `LAP_TIMES.TIME` is the same lap time as text, or race clock time in some odd rows. Race 847 lap 25 has about 7.5M ms for every driver. The 130% rule removes it.
- `PIT_STOPS.DURATION` is seconds, with m:ss format above 60 s. `MILLISECONDS` is authoritative. 517 stops are over 60 s.
- Pit stops cover 2011-2024 only (10,766 stops kept after the red-flag exclusion).
- `RESULTS`: 91 repeated race-driver pairs, all pre-1979. `result_id` is the grain.
- `POSITION` is `\N` for 10,945 rows. Of these, 10,943 have a non-numeric POSITIONTEXT (not classified). Two have numeric text: 2005 Australian GP (raceid 71), lapped finishers "+1 Lap" and "+2 Laps" at positions 11 and 14. These are classified.
- 2024 is incomplete: rounds 23 and 24 (raceid 1143, 1144) have no results. Standings stop at round 22. The 2024 champion does not count.
- Standings: the official DRIVER_STANDINGS snapshot matches every published champion 1950-2023 (checked against a hand-typed list, seed `official_world_champions`). Summed GP points would not match.
- Qualifying: race 256 has no timed entries. Race 255 has a 16:42.640 Q1 time that makes gaps about 920%. Qualifying constructor differs from RESULTS in 10 rows; fct_qualifying uses the qualifying constructor.
- Qualifying times use m:ss.SSS and can be 2-digit minutes (e.g. 16:42.640), so the parser allows any minute count.
