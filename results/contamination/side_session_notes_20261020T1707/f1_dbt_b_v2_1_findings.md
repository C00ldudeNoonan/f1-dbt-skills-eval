# F1 B_v2_1 findings (verified against ANALYTICS_DEV.F1_RAW_B_V2_1)

Project: ~/f1-eval-workspaces/B_v2_1/project, branch master, commit 951fbfb. `dbt build --profiles-dir .` passes (21 models, 1 seed, 101 tests incl. 2 unit tests + champion reconciliation).

The raw data matches the HC_1 notes: `\N` nulls, plus '' in qualifying Q2/Q3 (22/46 rows). 2024 has rounds 23-24 without results. 91 repeated race-driver pairs before 1979. Race 71 has numeric POSITIONTEXT 11/14. 517 pit stops over 60 s.
Also new here: 1997 Schumacher has DRIVER_STANDINGS POSITION 26 with POSITIONTEXT 'D'. We null the position. 19 never-classified driver-seasons are missing from the final standings snapshot, which matches the official tables. The champion list for 1950-2023 matches history.
