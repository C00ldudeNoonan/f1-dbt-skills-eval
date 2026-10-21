# F1 analytics (dbt)

dbt project that turns the raw Ergast/Kaggle Formula 1 load into tested, documented marts for race
results, championship standings, qualifying, pit stops, teammate comparisons and race pace.

- Source: `ANALYTICS_DEV.F1_RAW_HC_v2_1` (14 tables, all text, read-only). Coverage 1950 to 2024.
- Output: marts in `F1_DBT_HC_v2_1`. Staging and intermediate models go to `F1_DBT_HC_v2_1_staging` and `F1_DBT_HC_v2_1_intermediate`.

## Running it

```bash
dbt deps --profiles-dir .
dbt build --profiles-dir .
```

`dbt build` runs the models, the seed, 105 data tests (including 3 singular tests) and 4 unit tests. All pass.

## Layers

| Layer | Schema | Materialization | Purpose |
|-------|--------|-----------------|---------|
| `staging/stg_f1__*` | `_staging` | view | One model per raw table. Casts types, turns the `\N` sentinel into NULL, parses `m:ss.mmm` times. No business logic. |
| `intermediate/int_*` | `_intermediate` | table | Reusable business rules: season completeness, the latest standings snapshot, green-lap flags. |
| `marts/*` | (base) | table | The seven published models. |

## Models

| Model | Grain |
|-------|-------|
| `fct_results` | One Grand Prix result entry (`result_id`). Sprints excluded. |
| `dim_drivers` | One driver. |
| `mart_driver_season_standings` | Driver and season, at the latest round with standings. |
| `mart_constructor_season_pit_stops` | Constructor and season, pit stops of 60 s or less. |
| `fct_qualifying` | One qualifying entry. |
| `mart_teammate_head_to_head` | Season, constructor, driver and teammate (both orderings). |
| `fct_driver_race_pace` | Driver and race, with at least one green lap. |
| `fct_lap_times` | Driver and lap (incremental by race). |
| `fct_stints` | Driver and tyre stint, for races with pit stop data (incremental by race). |

| `fct_session_results` | One row per result across Grand Prix and sprint sessions (`session_type`, `source_result_id`). |
| `mart_driver_standings_by_round` | Driver and round, from the official standings. The base for season standings. |
| `mart_alt_points_standings` | What-if standings: driver and season, scored under the `points_system` var. |

What-if scoring: add a system as rows in `seeds/points_systems.csv` and run with `--vars '{points_system: <name>}'`.
The table holds one system per run, so the default `f1_current` is rebuilt by a plain `dbt build`.
Countback follows the rules in the model's docs; `dim_drivers.career_wins` is Grand Prix only and `career_sprint_wins` covers sprints.

Incremental models (`fct_lap_times`, `fct_stints`) use `delete+insert` with `race_id` as the key.
Each run rebuilds every race that is new or among the two most recent races already loaded, using the
`recent_races_filter` macro. Corrected lap times therefore flow through without a full refresh, and
older races are not touched. The timing provider's corrections are not replayed on races outside that window.

Supporting models: `int_season_completeness`, `int_driver_season_standings`, `int_lap_green_flags`.
Reference seed: `official_season_champions` (1950 to 2023).

## Design decisions

1. **Season completeness is a single model.** A season is complete only when every calendar race has results. `int_season_completeness` decides this, and the championship counts in `dim_drivers` and the standings use it. 2024 is complete in the current load. A season with an unloaded round would stay out of the champion counts until its last round arrives.
2. **Standings come from the official snapshot, not from summing race points.** `DRIVER_STANDINGS` already carries the official points, including the pre-1991 drop-score rules and sprint points from 2021. Summing `fct_results` does not match: 81 of 3,168 complete driver-seasons differ, for example 2023 Verstappen sums to 530 against an official 575 (the gap is sprint points). The mart takes the last round that has standings. Incomplete seasons are flagged `is_season_complete = false`.
3. **Finish position.** `finish_position` is `POSITION`, or `POSITIONTEXT` when `POSITION` is null but the text is numeric. This recovers the two lapped finishers in 2005 Australia. Letter codes (R, D, W, F, N, E) leave it null. `is_win` and `is_podium` are false when it is null.
4. **Result grain is `result_id`.** 85 race-driver pairs repeat before 1979, when one driver entered two cars. Teammate and standings logic take each driver's best `position_order` per race and constructor.
5. **Times are parsed once.** Lap and race times use the `MILLISECONDS` columns where they exist. Text times (`FASTESTLAPTIME`, `Q1` to `Q3`) go through the `lap_time_to_ms` macro, which returns NULL for anything that does not match `m:ss.mmm`. The macro avoids `TRY_TO_NUMBER`, which returns 0 for `'E'` in this warehouse.
6. **Pit stops over 60 s are excluded** from both the count and the median, as red-flag stoppages.
7. **Green laps** follow the four rules in `int_lap_green_flags`. The 130% threshold is measured against the fastest lap any driver set in that race, and a lap exactly at 130% stays green.
8. **Gap to pole.** `gap_to_pole_pct` is `gap / pole * 100`, so `0.512` means 0.512%.
9. **Tests are where the logic is hard.** Generic tests cover keys, relationships and ranges. Unit tests cover the finish-position fallback, the best-time coalesce, the 130% boundary and the time parser. Singular tests check the standings against the official-champions seed and check the green-lap rules.

## Data quirks

- `\N` is the null sentinel in every raw column. Qualifying `Q2` (22 rows) and `Q3` (46 rows) also hold empty strings. The staging macro treats both as NULL.
- Raw data ends at the 2024 season (last race 2024-12-08). The brief's "current season" is not in the load.
- 2024 was incomplete at the first load (rounds 23 and 24 had no results). Qatar (race 1143) and Abu Dhabi (race 1144) have since loaded, so 2024 is complete and its champion (Verstappen, 437 points, matching the official total) now counts. The raw `RESULTS` table has grown since the first load, so counts in this README reflect that first load.
- Lap data starts in 1996, pit stop data in 2011, qualifying in 1994, and fastest lap times in 2004. Models that need these return NULL or fewer rows for earlier seasons. Green-lap pit exclusions therefore only apply from 2011, so earlier races can include in and out laps.
- The 2014 Abu Dhabi finale awarded double points, so `points` goes up to 50.
- Races 780, 784 and 828 are shared drives with two winners. Both get `is_win`, so those races show two wins.
- 1997 Schumacher is in the standings at POSITION 26 with POSITIONTEXT `D` (excluded from the title). His 78 points are kept, but `championship_position` is null because the official table does not rank him.
- 19 driver-seasons have results but no standings row (non-classified entries). They are absent from `mart_driver_season_standings`, the same as the official table.
- Races 937 to 944 (2015 Manor) record constructor 206 (Marussia) in `QUALIFYING` and 209 (Manor) in `RESULTS`. Qualifying teammate pairs use each table's own constructor, so those races do not pair up.
- Some qualifying times are very slow (for example a 16:42 Q1 in 1995). Those produce large `gap_to_pole_pct` values, for example 922.86%. They are real entries in the source, so they are kept.
- The official `FASTESTLAPTIME` and the fastest lap in `LAP_TIMES` disagree for some races (2011 British GP: 94.908 s official, 93.391 s in `LAP_TIMES`). The green-lap threshold uses `LAP_TIMES`, as the brief specifies.
- `LAP_TIMES.TIME` has 43 values in `h:mm:ss`, and `PIT_STOPS.DURATION` mixes formats. Those text columns are not parsed, so the models use the millisecond columns instead.

## Verification

- Champions and final points match the official record for every season from 1950 to 2023. The test is `tests/assert_standings_match_official_champions.sql`, against the `official_season_champions` seed.
- 74 champions across the complete seasons, one per season (`tests/assert_one_champion_per_complete_season.sql`).
- The docs coverage audit reports 100% model descriptions.

## When the vendor changes the feed

The raw schema is maintained by the vendor and can change without notice. The 2026-10-21 migration renamed a table
and a column, dropped an unused column, moved race dates to DD/MM/YYYY and changed qualifying nulls to empty strings.

Three guards run on every build:

1. **Contract check (before any model).** `macros/assert_raw_source_contract.sql` runs as an on-run-start hook. It
   checks the tables, columns, minimum row counts and text formats this project reads. If anything no longer matches,
   the run stops before building and names each mismatch.
2. **Format tests.** `stg_f1__races.race_date` must parse. An unknown date format becomes NULL, and the not_null test fails.
3. **Build tests.** Unit tests, data tests and the champion checks run as usual.

When the contract check fails:

1. Fix the source identifier, column name or parser in `models/staging` (one place per change).
2. Update the contract in the same change, so the vendor change is visible in review.
3. Prove no numbers moved. Clone the marts before the change, then compare:

```bash
dbt run-operation compare_to_baseline --args '{baseline_schema: <schema holding the clones>}'
```

It compares every table and snapshot row for row and fails on any difference. A clone is zero-copy, for example
`create transient table <schema>.<name> clone <project schema>.<name>`.

The 2026-10-21 migration was verified this way: all 16 tables and snapshots matched their pre-migration copies
exactly, and the raw data matched row for row after mapping the renamed table and column and normalizing nulls.

## Duplicates and fan-out (2026-10-21)

On 2026-10-21 at 13:21 the vendor loaded two things twice: constructor 6 (Ferrari, once with a trailing space in the
name) and round 22's standings (23 rows under IDs offset by 100000). A join from results to constructors doubled
every Ferrari result: wins and points roughly doubled on the dashboard. Pit stops and the season standings were
not affected in the same way.

Guards now in place:

1. **Raw key checks (contract, before any model).** Each key that should be unique is checked. Keys repeated with
   identical values are collapsed in staging and logged as a NOTE. Keys repeated with different values stop the run.
2. **Raw value ranges (contract).** Points, positions, standings wins and lap or pit durations must fall in plausible ranges.
3. **Staging collapse and tests.** Constructors and standings collapse identical copies. Unit tests pin that behaviour, and
   a unique test on (race, driver) fails if copies ever disagree.
4. **Fan-out reconciliation.** `assert_fct_results_reconciles_with_staging` checks row count, distinct results, points and
   wins against staging. `assert_fct_session_results_reconciles_with_staging` checks row counts per session type.

After the fix, every table matched its pre-migration baseline row for row (`compare_to_baseline`).

## Public interfaces (for consuming teams)

`fct_results` and `dim_drivers` are public, owned by the `f1_core` group (F1 analytics team). Everything else in
this project is protected: other projects cannot reference it.

- **Contracts are enforced.** Column names and types are fixed. A change that breaks the contract fails the build
  before it reaches a consumer.
- **`fct_results`** is one row per Grand Prix result entry (grand prix only, not sprints). Use `result_id` as the key.
- **`dim_drivers`** is versioned. Version 2 is latest and is what `ref('dim_drivers')` returns by default.
  - Version 2 has `first_name` and `last_name` in place of `full_name`.
  - Version 1 keeps `full_name` and is deprecated on 2027-01-01. It keeps building until then.
  - Placeholder rows (`is_placeholder = true`) for late-arriving drivers are in both versions. Their names are
    `Unknown` / `Driver <id>` (v2) or `Unknown Driver <id>` (v1), and `current_number` is null.
  - To pin the old shape, use `ref('dim_drivers', v=1)`. Move to version 2 before 2027-01-01.
- A championship counts only when its season is complete. An unfinished season never adds one.

## Semantic Layer (self-serve metrics)

Metrics are defined on `fct_results` (race starts, wins, podiums, championship points, podium rate, points per start)
and reach nationality through `dim_drivers` (joined on the driver entity). Time-based metrics use the `race_date`
time dimension, backed by `metricflow_time_spine`.

| Metric | Definition |
|---|---|
| `race_starts` | Count of Grand Prix result entries |
| `wins` | Grand Prix wins (`is_win`) |
| `podiums` | Grand Prix podiums (`is_podium`) |
| `championship_points` | Sum of Grand Prix points |
| `podium_rate` | `podiums / race_starts` |
| `points_per_start` | `championship_points / race_starts` |

Dimensions: `race_date` (day grain), `season`, `constructor_name` (on results); `nationality`, `driver_ref` (on drivers).

Example queries (dbt Semantic Layer CLI, to run in a project connected to dbt Cloud):

```bash
# Season totals for 2024
dbt sl query --metrics race_starts,wins,podiums,championship_points,podium_rate,points_per_start --where "season = 2024"

# Wins and podiums by constructor
dbt sl query --metrics wins,podiums --group-by constructor_name

# Race starts by driver nationality, over time (monthly)
dbt sl query --metrics race_starts --group-by nationality,metric_time__month

# Points per start by season for a single constructor
dbt sl query --metrics points_per_start --group-by season --where "constructor_name = 'Ferrari'"
```

Expected values, computed from the same definitions in SQL (they match what the metrics should return):

| Query | Result |
|---|---|
| 2024 season: race starts / wins / podiums / points | 480 / 24 / 72 / 2,443 |
| 2024 podium rate / points per start | 0.150 / 5.09 |
| All-time Ferrari: race starts / wins / points | 2,439 / 249 / 11,091 |
| British drivers, 2020: starts / wins | 51 / 11 |

Not verified here: the dbt Cloud-backed commands (`dbt sl validate`, `dbt sl query`) need a dbt Cloud project, and this
project is not linked to one. The definitions parse locally (`dbt parse`) and the metrics reconcile with the SQL above,
but the Semantic Layer itself has not been queried end to end.

## Vendor B cross-check

A second feed (`VB_DRIVERS`, `VB_SESSIONS`, `VB_RESULTS`) covers 2018 to 2024 and uses its own ids. Our primary feed
stays the system of record. Vendor B is matched to our ids automatically, with no hand-kept id list.

- **Drivers (`dim_driver_crosswalk`).** Surnames and given names are compared with accents folded and letters only.
  The surname must match. The given name must match exactly or be a prefix (ALEX matches Alexander). The three-letter
  code breaks ties. The top candidate must be unique. An unmatched driver fails the build (`driver_id` not null).
  `seeds/vendor_b_driver_overrides.csv` is the only manual step, for a genuinely ambiguous driver, with a reason.
- **Sessions (`dim_session_crosswalk`).** A Vendor B session matches our session of the same season and type within
  three days, with the most shared drivers. At least 80% of its entries must be found in our session. An unmatched
  session fails the build (`race_id` not null). Two Vendor B sessions may not match the same race and type.
- **Discrepancies (`mart_vendor_result_discrepancies`).** One row per entry per disagreement: `points`, `position`
  (classified finishers only; unclassified in both feeds is not a discrepancy), `missing_in_vendor_b`, and
  `missing_in_vendor_a`. The raw contract also checks the Vendor B tables, so a missing table or column stops the run.

At build time all 41 Vendor B drivers match, and all 167 sessions for 2018 to 2024 match. The mart shows 11
discrepancies: 3 missing in Vendor B, 3 points, 1 sprint point, 4 positions. Our feed remains the system of record.

## Car telemetry (incremental)

`CAR_TELEMETRY` holds about 20 million samples from 2022 (67 races, about 296,000 samples per race). Samples can arrive
weeks after the race, so `_LOADED_AT` (the load time) is the watermark, not the race date.

- **`fct_telemetry`** is incremental by race. A routine run finds the races that gained samples since the last load (less a
  48-hour lookback), and rebuilds each of those races in full. A late sample for an old race rebuilds that race.
- **`mart_lap_telemetry_summary`** is incremental by race too. It rebuilds the races `fct_telemetry` just changed, so the
  summary always matches its samples.
- Both use `delete+insert` on `race_id` and cluster by `race_id`, so a replaced race leaves no stale rows.

Cost of a routine run compared with a full rebuild (estimated in rows; bytes scanned have not been measured here):

| Work | Full rebuild | Routine run (new samples for the latest race) | Late samples for one old race |
|---|---|---|---|
| Samples read to build `fct_telemetry` | 19.8 million | about 0.3 million (one race) | about 0.3 million (one race) |
| Samples read to build the summary | 19.8 million | about 0.3 million | about 0.3 million |
| Raw scan to find changed races | — | pruned by `_LOADED_AT` (recent loads only) | pruned by `_LOADED_AT` |

A full rebuild is about 66 times the work of a one-race routine run, roughly 1.5% of the work per race. Runs that touch
many races (a replayed batch) cost in proportion to the races they touch.

The routine tests read only recent loads. The full-table key audit is tagged `weekly_full_scan`. Routine runs can leave it
out with `dbt build --exclude tag:weekly_full_scan`, and a weekly run includes it.

Assumptions to check: `_LOADED_AT` is set when a sample lands and never goes backwards, and the raw table is loaded in
roughly insertion order, so `_LOADED_AT` filters prune partitions. Confirm the pruning in the query profile in production.

## CI for pull requests

Pull requests build only what they change. Everything else is read from production, so CI does not rebuild the whole
project.

**Targets** (in `profiles.yml`; `dev` is still the default):

| Target | Schema | Used for |
|---|---|---|
| `dev` | `F1_DBT_HC_v2_1` (and suffixes) | Day-to-day development |
| `prod` | `F1_DBT_HC_v2_1_PROD` (and suffixes) | The production build |
| `ci` | `F1_DBT_HC_v2_1_CI` (and suffixes) | Pull request builds |

**Production state** lives in `prod-artifacts/` (`manifest.json` and `run_results.json`). CI compares against it.
Refresh it after each production deployment:

```bash
dbt build --target prod --profiles-dir .
cp target/manifest.json target/run_results.json prod-artifacts/
git add prod-artifacts && git commit -m "Refresh production state"
```

**Running CI** from the project root, with no arguments:

```bash
scripts/ci.sh
```

The script:

1. Fails if `prod-artifacts/manifest.json` is missing.
2. Selects nodes with `state:modified+`: every model, test, seed or snapshot that changed relative to the production
   state, plus everything downstream of it.
3. If nothing is selected, it exits 0 without building.
4. Otherwise it runs `dbt build --target ci --defer --state prod-artifacts` on that selection. Unchanged upstream models
   are read from production through `--defer`, not rebuilt. The weekly full-table telemetry audit is excluded.
5. Exits non-zero if any model, test or snapshot fails, because `set -e` passes dbt's exit code through.

Selection was checked with `dbt ls`, using a parse-only baseline. Editing one model selected that model, its downstream
mart and their tests (14 nodes), and an unchanged project selected none. A full run was also checked end to end
with a temporary change to `dim_session_crosswalk`: 14 nodes built into `F1_DBT_HC_v2_1_CI`, and their upstream models
read from `F1_DBT_HC_v2_1_PROD`. The production state in `prod-artifacts/` was generated from `dbt build --target prod` (265 of 265).

**Known gaps:** `state:modified` compares node checksums, so a change that only affects data (a new raw load) is not
detected. The production state must be refreshed after every production build, or CI compares against a stale baseline.

## Analysis: driver overperformance and pit stops

Two leadership questions are answered in [docs/analysis/leadership_questions.md](docs/analysis/leadership_questions.md).
The supporting models are `mart_driver_overperformance` (teammate-relative, with intervals and an era split) and
`mart_pit_stop_trend_summary` (circuit-adjusted pit stop trend). Both read from the tested marts above.

