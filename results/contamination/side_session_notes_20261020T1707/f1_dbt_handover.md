# F1 dbt project hand-over

Project: ~/f1-eval-workspaces/HA_1/project (branch `f1-dbt-project`, commit 06f733a, not pushed).
`dbt build --profiles-dir .` passes: 12 models, 73 tests.

Data findings from ANALYTICS_DEV.F1_RAW_HA_1:
- Nulls are the literal string `\N`.
- 2024 is incomplete: rounds 23 and 24 (RACEIDs 1143, 1144) have no results. Standings for 2024 are as of round 22. Champions are not counted for 2024.
- Raw data ends at 2024 (no 2025/2026 seasons).
- RESULTS has duplicate race/driver pairs in early seasons (two cars in one event). result_id is the grain.
- 2005 Indianapolis: two rows have POSITION `\N` but a numeric POSITIONTEXT. Treated as not classified.
- Standings champions checked against history for all seasons 1950-2023.
