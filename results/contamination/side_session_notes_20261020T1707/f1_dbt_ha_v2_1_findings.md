# F1 dbt, HA v2.1 hand-over

Project: ~/f1-eval-workspaces/HA_v2_1/project, branch `f1-dbt-ha-v2-1`, commit 93af945 (not pushed).
`dbt build` passes: 23 models, 110 tests, 1 seed (134 of 134). Raw schema: ANALYTICS_DEV.F1_RAW_HA_V2_1.

Findings checked against the v2.1 raw data:
- Null sentinel is `\N`. Qualifying Q2/Q3 also has empty strings (46 Q3 rows, 2023-2024).
- RACES.ROUND is TEXT. max(round) sorts lexically (9 > 22). This picks the wrong round for any season with 10+ rounds. Cast to int first.
- 2005 Australian GP: two lapped finishers have POSITION `\N` and numeric POSITIONTEXT (11, 14). They are classified.
- 2024 is incomplete: rounds 23 and 24 have no results. Standings are as of round 22 (VER 403, NOR 340). No 2024 title counted.
- DRIVER_STANDINGS snapshot matches published champions for every season 1950-2023 (checked against the seed, which is in the project).
- Pit stops 2011-2024: 11,283 rows, 517 over 60 s. 10,766 kept.
- Lap times from 1996, pit stops from 2011.
