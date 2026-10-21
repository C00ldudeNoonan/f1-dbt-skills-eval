# F1 A_v2_1 findings (verified against ANALYTICS_DEV.F1_RAW_A_V2_1)

Project: ~/f1-eval-workspaces/A_v2_1/project, branch `f1-dbt-project`. `dbt build` passes (22 models, 151 tests, 1 seed, 4 unit tests).

Agrees with HA_1/HC_1 notes (\N nulls, 2024 incomplete after round 22, race 71 classified lapped finishers, standings snapshot matches champions 1950-2023, pit stops 2011-2024 with 517 over 60s).
New quirks found here:
- QUALIFYING has 68 empty-string times in addition to \N.
- QUALIFYING 1995 Japanese GP (race 255) driver 87 has Q1 = 16:42.640 (data error, kept as-is). 1995 Australian GP (race 256) has entries but no times.
- QUALIFYING constructor differs from RESULTS for 10 rows: 2015 Manor drivers recorded as 206 (Marussia) in qualifying, 209 (Manor) in results, races 937-944.
- 1997: Schumacher is in DRIVER_STANDINGS at position 26 with positiontext 'D' (excluded). Mart sets championship_position null.
- 19 driver-seasons have results but no DRIVER_STANDINGS row (DNQ-only or zero-point DSQ entries).
- Shared drives: races 780, 784, 828 have two winners; both credited.
