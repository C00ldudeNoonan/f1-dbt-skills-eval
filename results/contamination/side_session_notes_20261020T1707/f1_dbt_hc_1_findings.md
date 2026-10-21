# F1 HC_1 data findings (verified against ANALYTICS_DEV.F1_RAW_HC_1)

Project: ~/f1-eval-workspaces/HC_1/project, branch `f1-dbt-hc-1`, commit be95036. `dbt build` passes (12 models, 81 tests, 1 seed, 6 unit tests).

- `\N` is the null sentinel in every raw table.
- RESULTS grain is `resultid`. 91 race-driver pairs repeat, all before 1979 (two cars). None has pit stop data.
- Raw data ends at 2024. No 2025+ seasons.
- 2024 is incomplete: rounds 23 and 24 (raceid 1143, 1144) have no results. 2024 standings stop at round 22. No 2024 champion is counted.
- Standings: use the raw DRIVER_STANDINGS snapshot. Summed GP points don't match before 1991 (drop scores). From 2021 the official totals include sprint points. The raw snapshot matches the published champion for every season 1950–2023.
- Correction to the HA_1 hand-over: race 71 is the 2005 Australian GP, not Indianapolis. Its two lapped finishers ("+1 Lap", "+2 Laps") have POSITION `\N` but POSITIONTEXT 11 and 14. They are classified, so they get finish positions 11 and 14 (0 points).
- Snowflake quirk: TRY_TO_NUMBER('E') returns 0. Parse text positions with a digit regex, not try_to_number alone.
- Fastest lap comes from FASTESTLAPTIME (m:ss.mmm). MILLISECONDS is race time.
- Pit stops run 2011–2024, 11,283 rows. 517 are over 60 s and excluded.
