# F1 C_v2_1 findings (verified against ANALYTICS_DEV.F1_RAW_C_V2_1)

Project: ~/f1-eval-workspaces/C_v2_1/project, branch `f1-dbt-project`. `dbt build` passes: 22 models, 124 data tests, 7 unit tests, 1 seed (154 nodes).

Matches the HC_1 note. What's new or different in this schema:
- RESULTS: 85 repeated race/driver pairs here, not 91.
- QUALIFYING Q2/Q3 have empty strings (22 and 46 rows) as well as `\N`.
- DRIVERS: driver 861 nationality is 'Argentinian ' (trailing space, and every other Argentine driver is 'Argentine').
- QUALIFYING constructor_id differs from RESULTS for 10 rows of 2015 Manor Marussia (206 vs 209).
- 19 driver-seasons with GP results have no row in the final DRIVER_STANDINGS snapshot (1967–2007, about half of them 1992–93 entries that never qualified).
- Official podium counts count rows, not distinct races: Farina 20 and Trintignant 10, because both had two shared-car podiums in race 792 (1955 Argentine GP).
- DRIVER_STANDINGS: the snapshot's P1 and points match the published champion for every season 1950–2023. 2024 is as of round 22.
