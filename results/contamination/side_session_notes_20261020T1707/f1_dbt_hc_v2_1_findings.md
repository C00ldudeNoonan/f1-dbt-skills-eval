# F1 HC_v2_1 data findings (verified against ANALYTICS_DEV.F1_RAW_HC_v2_1)

Project: ~/f1-eval-workspaces/HC_v2_1/project (uncommitted, master). `dbt build` passes: 19 models, seed, 106 data tests, 4 unit tests, 3 singular tests.

- Null sentinel is the literal `\N` in every column. All columns are TEXT.
- Coverage: races 1950-2024 (last race 2024-12-08). Lap data 1996+, pit stops 2011+, qualifying 1994+, FASTESTLAPTIME 2004+.
- 2024 is incomplete: race IDs 1143 (Qatar, round 23) and 1144 (Abu Dhabi, round 24) have no results. 2024 standings stop at round 22. No 2024 champion counted.
- RESULTS repeats 85 race-driver pairs, all 1950-1978 (two cars). result_id is the grain.
- 2005 Australian GP (race 71): two lapped finishers have POSITION `\N` and numeric POSITIONTEXT 11 and 14 (statuses +1 Lap, +2 Laps). They are classified.
- DRIVER_STANDINGS final-round champion matches the official record for every season 1950-2023, including points (2021 Verstappen 395.5, 2023 575). Summing GP points from RESULTS does not match: 81 of 3,168 complete driver-seasons differ (sprint points 2021+, drop scores before 1991).
- LAP_TIMES.TIME has 43 `h:mm:ss` values. MILLISECONDS is always integer. PIT_STOPS.DURATION mixes formats, so use MILLISECONDS. 517 stops are over 60 s.
- Sakhir 2020 (race 1046) fastest lap 55.404 s is real (official FASTESTLAPTIME matches LAP_TIMES min).
- Snowflake quirk: TRY_TO_NUMBER('E') returns 0 here. Parse text times with a regex.
- 2014 Abu Dhabi (race 918) had double points (50/36/30), so points max is 50.
- QUALIFYING Q2 has 22 empty strings and Q3 has 46, in addition to `\N`. Handled as NULL.
- 1997 Schumacher: standings POSITION 26, POSITIONTEXT `D`, 78 points. Championship position is null in the mart, points kept.
- 19 driver-seasons have results but no standings row (not ranked officially).
- Shared drives 780, 784 and 828 have two winners; both credited.
- 2015 Manor (races 937 to 944): QUALIFYING constructor 206 (Marussia) vs RESULTS 209 (Manor).
