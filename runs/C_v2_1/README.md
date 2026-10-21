# F1 analytics dbt project

Models the Ergast/Kaggle Formula 1 dataset (1950 to the latest loaded season) in
Snowflake for the F1 analytics team and for other teams that build on it.

- Raw data: `ANALYTICS_DEV.F1_RAW_C_v2_1`. It is read-only and declared as the `f1_raw` source.
- Output: `ANALYTICS_DEV.F1_DBT_C_v2_1_<layer>`, for example `F1_DBT_C_v2_1_MARTS`.

```bash
dbt build          # seed, run, test (data tests and unit tests)
dbt docs generate  # browse lineage and column docs
```

## Analysis: leadership questions

[`docs/leadership_questions.md`](docs/leadership_questions.md) answers two
leadership questions. It covers definitions, assumptions, limitations, and
where each question misleads.

- **"Which drivers overperform their car?"** Answered by
  `mart_driver_vs_teammates` (career) and `mart_driver_season_vs_teammate`.
  They're built on `int_f1__teammate_qualifying_comparisons`: same-car
  qualifying gaps from 2006, adjusted for teammate strength, with Wilson
  confidence bounds and trust tiers.
- **"Are pit stops getting faster?"** Answered by `mart_race_pit_lane_times`
  and `mart_pit_lane_time_trend`: pit-lane time compared with each circuit's
  own norm, within the post-mid-2013 speed-limit regime.

## Environments and CI

| Target | Schema prefix | Used for |
|---|---|---|
| `dev` (default) | `F1_DBT_C_v2_1_<layer>` | Local development: `dbt build` |
| `prod` | `F1_DBT_C_v2_1_PROD_<layer>` | Production: `scripts/prod.sh` |
| `ci` | `F1_DBT_C_v2_1_CI_<layer>` | Pull-request checks: `scripts/ci.sh` |

**Production (`scripts/prod.sh`).** Builds everything into `prod`, then copies
`manifest.json`, `run_results.json` and `semantic_manifest.json` into
`prod-artifacts/`. Run it after every merge to `main` and commit the refreshed
`prod-artifacts/`, which is CI's definition of "what production looks like".

**Pull requests (`scripts/ci.sh`, no arguments, from the project root):**
1. Lists `state:modified+` against `prod-artifacts/`: the models, seeds,
   snapshots and tests whose definition (SQL, YAML config, macros used)
   differs from production, plus everything downstream. If nothing changed,
   it exits 0 without building.
2. Drops the CI schemas, so leftovers from an earlier pull request can't shadow
   production tables.
3. Creates the selected incremental models as empty tables (`--empty`, no
   data read). Their unit tests mock `this` and need the relation to exist.
4. Runs `dbt build --select state:modified+ --defer --favor-state --state
   prod-artifacts` into `ci`. Changed models and their descendants are built and
   tested. Every unchanged upstream `ref` resolves to the production relation
   instead of being rebuilt.
5. Exits non-zero if any step fails (`set -euo pipefail`; dbt returns 1 on any
   failing model or test).

Verified:
- No changes: nothing built.
- A change to `mart_teammate_head_to_head`: 1 model and its 3 tests, reading
  `fct_results` and `fct_qualifying` from prod.
- A change to `stg_f1__lap_times`: 8 models, 32 tests and 10 unit tests,
  including both incremental lap models.
- A change that breaks a unit test: exit code 1.

Notes:
- Artifacts are written to `target-prod/` and `target-ci/` (git-ignored), so
  they never mix with dev's `target/`.
- A changed incremental model is rebuilt in full in CI (the empty table is
  loaded completely), so its new logic is tested against all history.
- `state:modified` compares against the committed manifest. If
  `prod-artifacts/` is stale, CI builds more than it needs to (still correct)
  or defers to objects that no longer match. Refresh it with `scripts/prod.sh`.

## Layout

| Layer | Path | Materialization | Purpose |
|---|---|---|---|
| staging | `models/staging/f1/stg_f1__*` | view | One model per raw table. Casts text to types, turns the `\N` sentinel and empty strings into nulls, renames columns to snake_case. No business logic. |
| intermediate | `models/intermediate/int_f1__*` | view | Shared building blocks. `int_f1__race_calendar` is the one place that defines a completed round and a completed season. |
| marts | `models/marts/{core,championship,race_engineering}` | table | The models consumers use. `access: public`, contracts enforced. |
| monitoring | `models/monitoring/mon_*` | view | Live data-quality monitors, such as `mon_late_arriving_drivers`. |
| snapshots | `snapshots/` | snapshot | `snp_drivers`: type 2 history of raw drivers. |
| seeds | `seeds/` | table | Reference data. `world_drivers_champions` is used to check standings against published history. |

Public interface (other teams' dbt projects may `ref` these):

| Model | Grain | Versions |
|---|---|---|
| `fct_results` | Grand Prix result entry (`result_id`). Sprints excluded. | unversioned |
| `dim_drivers` | Driver, including placeholder rows for late-arriving drivers | v2 (latest), v1 (deprecated 2027-01-01) |

Both are in the `f1_analytics` group, `access: public`, and contract-enforced.
Every other model is `protected`: it can be used inside this project but isn't a
supported interface, and it may change without a version bump.

Other models in this project (protected):

| Model | Grain |
|---|---|
| `fct_session_results` | Result entry across Grand Prix and sprint sessions (`session_type`, `source_result_id`) |
| `fct_qualifying` | Qualifying entry (`qualify_id`) |
| `fct_driver_race_pace` | Driver × race with at least one green-flag lap |
| `fct_lap_times`, `fct_stints` | Driver × race × lap, and driver × race × stint (incremental) |
| `mart_driver_standings_by_round` | Driver × completed round in the official standings |
| `mart_driver_season_standings` | Driver × season, as of the latest completed round |
| `mart_alt_points_standings_by_system`, `mart_alt_points_standings` | What-if standings |
| `mart_constructor_season_pit_stops` | Constructor × season with pit stop data |
| `mart_teammate_head_to_head` | Season × constructor × driver × teammate (both orderings) |

### dim_drivers v2: what consumers need to know

- **Change:** v2 replaces `full_name` with `first_name` and `last_name`. Every
  other column, the grain and the row set are identical to v1. Both versions
  are built from the same model, `int_f1__driver_profiles`.
- **dbt consumers:** `ref('f1', 'dim_drivers')` now resolves to **v2**. If you
  aren't ready, pin v1 with `ref('f1', 'dim_drivers', v=1)`. dbt warns that it's
  deprecated. Move to v2 before **2027-01-01**, after which v1 will be removed.
- **Direct SQL consumers:** the `DIM_DRIVERS` table keeps the **v1** shape until
  v1 is removed. v2 is at `DIM_DRIVERS_V2`. At removal, `DIM_DRIVERS` will switch
  to the latest version, so move SQL readers to `DIM_DRIVERS_V2` before then.
- **Migrating:** `first_name || ' ' || last_name` equals v1 `full_name` for every
  row, including placeholders, so the change is mechanical.
- **Placeholders** (`is_placeholder = true`, driver_id seen in results before the
  driver record arrives) exist in both versions. v1:
  `full_name = 'Unknown driver (id <id>)'`. v2: `first_name = 'Unknown'`,
  `last_name = 'driver (id <id>)'`. Placeholders are replaced by real values on
  the first run after the record arrives.
- `forename` and `surname` are still in v2 and match `first_name` and
  `last_name`. Treat them as legacy columns; they may be dropped in a later version.
- The `latest_version_pointer` is disabled for `dim_drivers`, because Fusion
  would otherwise replace the v1 `DIM_DRIVERS` table with a view of v2.
  `assert_dim_drivers_v1_window_open` fails the build if that happens.

Column definitions are in the YAML next to each model and in `dbt docs`.

## Conventions

- Parse raw text only through the macros in `macros/parsing.sql` (`clean_text`,
  `to_integer`, `to_decimal`, `time_to_ms`). Don't use `try_to_number` on its own:
  Snowflake parses some letters (for example `'E'`) as 0.
- Every source column is text, so staging is where the types get fixed. Downstream
  models never read `source()` directly.
- Times are integer milliseconds and the column names end in `_ms`.
- Public models have enforced contracts. To make a breaking change (rename, drop or
  retype a column), add a new model version with a migration window. Don't edit
  the model in place.
- Generic tests `unique_combination_of_columns` and `expression_is_true` live in
  `tests/generic/`, so the project has no package dependencies.
- Unit tests (`models/_unit_tests.yml`) cover the parsing rules, the green-lap
  rules, gap to pole, teammate pairing, standings exclusions and title counting.
  In production you can skip them with `--exclude-resource-type unit_test`.

## Definitions that matter for reconciliation

- **Completed round**: the race has at least one Grand Prix result.
  **Completed season**: every race on that season's calendar has results.
- **Standings** come from the official standings snapshot after the latest
  completed round. They are not summed from results, because official totals
  include sprint points (2021 on), dropped scores (most seasons before 1991) and
  shared drives. A test checks that P1 and the points total match the published
  champion for every completed season.
- **Championships** in `dim_drivers` only count completed seasons.
- **Career starts** count distinct Grands Prix entered, including entries that did
  not qualify. **Wins and podiums** count each classification, as official records
  do, so Farina's two shared-car podiums in the 1955 Argentine GP both count.
- **Green-flag lap**: any lap except lap 1, a lap on which the driver pitted, the
  lap after a pit stop, and any lap slower than 130% of the race's fastest lap.
  A lap at exactly 130% counts as green.

## Car telemetry (cost-aware incremental design)

`CAR_TELEMETRY` (about 20M rows from 2022, 4 samples per second per car)
feeds `fct_telemetry` (one row per sample) and `mart_lap_telemetry_summary` (one
row per driver per lap). Samples can land weeks after a race, marked by
`_LOADED_AT`.

**Design.** The race is the unit of work. Both models are incremental with
`delete+insert` on `race_id`:
1. `telemetry_races_to_process` reads the target's high-water mark
   (`max(source_loaded_at)`, answered from metadata) and subtracts a lookback
   (`telemetry_lookback_minutes`, default 120) for loader commit lag.
2. It asks raw for the distinct races loaded after that point. The timestamp
   is inlined as a literal, so Snowflake prunes micro-partitions; raw lands in
   load order, so new rows sit in the newest partitions.
3. The model reads raw for only those races (inlined `race_id in (...)`),
   keeps the latest copy of any resent sample, and replaces those races.
4. The summary does the same off `fct_telemetry`. Its high-water mark is
   `telemetry_loaded_at`, so a late sample re-aggregates its race and every
   lap stays exact.
5. Rows are written in race order. Without that, the full rebuild leaves races
   spread over every micro-partition, and deleting one race rewrites the whole
   table (411 MB measured, against 0.1 MB with ordering). It uses no automatic
   clustering, so it costs no clustering credits.

Tests stay cheap. Row-level tests on `fct_telemetry` are scoped to rows the
current run wrote (`processed_at` after run start, as a constant). Completeness
checks use only total row counts, which Snowflake answers from metadata:
- `assert_telemetry_summary_complete` (error): the summary covers every fact row.
- `assert_telemetry_complete` (warn): fact rows equal raw rows. A gap means
  resent duplicates or missed samples.

**Measured cost** (bytes scanned, from Snowflake query history):

| Run | MB scanned | Share of full rebuild |
|---|---|---|
| Full rebuild (`--full-refresh`) | ~1,026 | 100% |
| Routine run, nothing new (reprocesses the latest race in the lookback window) | ~35 | ~3% |
| Routine run with a late sample for a 2022 race (two races rebuilt) | ~146 | ~14% |

At this size raw is only 12 micro-partitions, so pruning is coarse. As the table
grows, a routine run's cost stays roughly constant (one or two races) while a
full rebuild keeps growing.

**Operations.**
- Set `telemetry_lookback_minutes` to 0 if the loader guarantees in-order
  `_LOADED_AT`. That avoids re-reading the latest race every run.
- A fresh environment needs `dbt run --select fct_telemetry+ --full-refresh`
  before the first `dbt build`. The incremental unit tests mock `this` and
  need the tables to exist (`fct_lap_times` and `fct_stints` behave the same).
- For end-to-end tests against a copy, override the source schema with
  `--vars '{telemetry_raw_schema: <schema>}'`. A sandbox test injected a late
  sample for 2022 Bahrain and a corrected resend. The next routine run rebuilt
  that race, kept the corrected value, and the lap went from 270 to 271
  samples.

## Vendor B cross-check feed

Vendor B (`VB_DRIVERS`, `VB_SESSIONS`, `VB_RESULTS`, 2018 onwards) shares no ids
with our feed. Models live in `models/staging/vendor_b` and `models/marts/vendor_b`
(schema `..._VENDOR_B`). Our feed stays the system of record.

**Session matching (`dim_session_crosswalk`).** A Vendor B session matches one
of our sessions when all of these hold:
- same season and session type;
- dates within one day (allows for UTC versus local dates);
- Vendor B's meeting name equals our circuit location, ignoring accents and
  case (`Montmeló`, `São Paulo`).

The closest start time wins. It also separates 2020's two races at Sakhir,
Silverstone and Spielberg. The 2021 sprints have no Vendor B start time and
match on date. All 167 sessions match automatically.

**Driver matching (`dim_driver_crosswalk`).** No single attribute is a safe key:
racing numbers repeat, names are unaccented or shortened (`PEREZ`,
`ALBON Alex`), and codes repeat across eras. The matcher:
1. Takes as candidates our drivers who share at least one matched session with
   the Vendor B driver.
2. Gives each candidate an identity score: one point each for the same code,
   surname, forename (accent- and case-insensitive) and racing number.
3. Counts agreeing sessions: shared sessions with the same grid slot or the
   same finishing position.
4. Ranks by identity score, then agreeing sessions.
5. Accepts the top candidate only if it has at least one identity point,
   agrees in at least half of the Vendor B driver's sessions, and strictly
   beats the runner-up.

All 41 drivers match automatically, each with 100% session agreement. The
evidence step matters for `RESERVE Sam`, who started 20th in Qatar 2024 level
with Ocon in our feed. The identity signals pick driver 9001.

**Overrides and failures.** `seeds/vendor_b_driver_overrides.csv` and
`seeds/vendor_b_session_overrides.csv` (both empty) win over automatic matches.
They're for genuinely ambiguous cases, and each row needs a `reason`. These tests
fail the build: `vendor_b_session_unmatched`, `vendor_b_driver_unmatched`,
`vendor_b_sessions_map_one_to_one`, `vendor_b_drivers_map_one_to_one` and
`assert_vendor_b_results_fully_mapped`. `best_candidate_driver_id` in the
crosswalk shows what an override would need.

**Discrepancies (`mart_vendor_result_discrepancies`).** A full outer join of
both feeds on race, session type and driver, for the seasons Vendor B covers.
Types are `missing_in_vendor_b`, `missing_in_vendor_a`, `points`, and
`position` (classified finishing position). Unclassified in both feeds isn't a
position discrepancy, even when the codes differ (`R` vs `DNF`). Today there are
11: 3 entries missing in Vendor B, 4 points and 4 position differences.

## Semantic Layer

Metrics use the latest (Fusion) spec and are defined in
`models/marts/core/_core__models.yml`. `time_spine_daily` (1950 to the end of
next year, in the `..._SEMANTIC` schema) provides `metric_time`.

| Semantic model | Built on | Entities | Dimensions |
|---|---|---|---|
| `grand_prix_results` | `fct_results` | `result` (primary), `driver`, `constructor`, `race` | `result__race_date` (time, the default for `metric_time`), `result__season`, `result__round`, `result__constructor_name`, `result__status` |
| `drivers` | `dim_drivers` (latest version) | `driver` (primary) | `driver__driver_ref`, `driver__nationality`, `driver__is_placeholder` |

| Metric | Definition |
|---|---|
| `race_starts` | Count of Grand Prix result entries (rows of `fct_results`). This counts entries, not distinct races, unlike `dim_drivers.career_starts`. |
| `wins` | Grand Prix wins (`is_win`) |
| `podiums` | Grand Prix podiums (`is_podium`) |
| `championship_points` | Sum of Grand Prix points as scored per race. Excludes sprint points, and before 1991 doesn't apply dropped scores, so it isn't the official championship total. |
| `podium_rate` | `podiums / race_starts` |
| `points_per_start` | `championship_points / race_starts` |

Example queries (`dbt sl query` on the dbt platform; with the MetricFlow CLI
use `mf query` with the same arguments):

```bash
# Driver season summary for 2023
dbt sl query --metrics race_starts,wins,podiums,podium_rate,points_per_start \
  --group-by driver__driver_ref --where "{{ Dimension('result__season') }} = 2023" \
  --order-by -wins

# Wins by driver nationality, all time
dbt sl query --metrics wins,podiums --group-by driver__nationality --order-by -wins

# Constructor points per season since 2014
dbt sl query --metrics championship_points,points_per_start \
  --group-by result__season,result__constructor_name \
  --where "{{ Dimension('result__season') }} >= 2014"

# Wins over time, by year (metric_time is the race date)
dbt sl query --metrics wins,race_starts --group-by metric_time__year

# One driver's podium rate by season, real drivers only
dbt sl query --metrics podium_rate --group-by result__season \
  --where "{{ Dimension('driver__driver_ref') }} = 'hamilton' and not {{ Dimension('driver__is_placeholder') }}"
```

Validation: `dbt parse` builds the semantic manifest. Full semantic
validation (`dbt sl validate`) needs a dbt platform project in
`dbt_cloud.yml`, which this environment doesn't have, so `dbt parse` reports
"Skipping semantic manifest validation". Run `dbt sl validate` once the
project is connected to the dbt platform.

## Sessions and what-if scoring

- `int_f1__session_results` combines Grand Prix and sprint results and applies
  the joins once. `fct_results` is its `session_type = 'race'` slice and
  `fct_session_results` is all of it. `dim_drivers.career_wins` counts Grand Prix
  wins only. Sprint wins are in `career_sprint_wins`.
- Points systems are data: `seeds/points_systems.csv` has one row per system and
  position. To add a system, add its rows and run `dbt build`.
  `mart_alt_points_standings_by_system` scores every system.
  `mart_alt_points_standings` shows one, chosen with
  `--vars '{alt_points_system: fia_1991}'` (default `fia_2010`). A test fails if
  the var names a system that isn't in the seed.
- Scoring rules: each classified Grand Prix entry scores on its own, by
  `position_order`. Sprints and fastest-lap points don't count. Drivers are
  ranked by points, then countback through 10th place, then lowest `driver_id`.
  A test checks `fia_2010` against the official points for 2010–2013 and
  2015–2018, the seasons when that was the real system.

## Incremental models

`fct_lap_times` and `fct_stints` are incremental and use `delete+insert` on
`race_id`, so each run replaces whole races.

- `fct_lap_times` loads races that aren't in the table yet. It also reloads the two
  most recent races already loaded (by season and round), because the timing
  provider reissues corrected laps for those. The var
  `lap_times_correction_window_races` sets how many races it reloads.
- `fct_stints` rebuilds a race when that race's `fct_lap_times.loaded_at` is newer
  than the `laps_loaded_at` the stints were built from. It also builds races that
  have pit stops but no stints yet. Lap corrections and new races therefore flow
  through without a full refresh.
- `assert_lap_times_match_source` (warn) compares the table with the source. If it
  fires, a correction arrived for an older race. Fix it with
  `dbt build --select fct_lap_times+ --full-refresh`.
- 53 pit stops are on a driver's last recorded lap. The empty stint that would
  follow is dropped.

## Driver history and late-arriving drivers

- `snp_drivers` (check strategy on number, code, names, nationality and date of
  birth) keeps every version of a driver's record. Raw `drivers` only holds current
  values, so history starts from the first snapshot run. `dbt build` runs the
  snapshot. The snapshot reads the cleaned `stg_f1__drivers`, so changing how
  staging cleans those columns creates a new version for every affected driver.
- `dim_drivers.current_number` is the permanent number as of the latest load.
- Results can arrive before the driver's record. Facts never inner-join to
  drivers, so those results stay in `fct_results` and everything downstream.
  `mon_late_arriving_drivers` is a live view that lists every driver_id the facts
  reference but `drivers` lacks, with counts per fact type:
  `select sum(orphan_result_count) from ..._monitoring.mon_late_arriving_drivers`.
  `dim_drivers` adds a placeholder row for each of them (`is_placeholder`,
  `driver_ref` = `unknown_driver_<id>`). On the first run after the real record
  arrives, the placeholder is replaced by the real values automatically. A
  warn-level test reports open orphans on every build.

## Vendor contract (detecting upstream changes)

Every raw table in `_f1__sources.yml` carries contract tests. They run before
the staging models that read the table. In `dbt build`, a failure skips
everything downstream, so the build stops at the source with a test name that
says what changed. Numbers downstream never change silently.

| Test | Severity | Catches |
|---|---|---|
| `source_contract_<table>_columns_present` | error | Renamed or dropped columns, and renamed or missing tables (every column reported missing) |
| `source_contract_<table>_no_unexpected_columns` | warn | New columns the vendor added |
| `source_contract_<table>_<column>_format` | error | Values that no longer match the agreed text format: integers, decimals, `DD/MM/YYYY` or ISO dates, clock times, lap times, classification codes and null tokens. The failing values and counts are in the test output. |

When the vendor announces a change, or a contract test fails:

1. Clone the current outputs before changing anything: `dbt run-operation clone_baseline`.
2. Update `_f1__sources.yml` and the staging SQL. Then run `dbt clean` (Fusion
   caches source schemas) and `dbt build --full-refresh`, so the incremental
   models are rebuilt from the new feed too.
3. Run `dbt run-operation compare_to_baseline`. Every table should log `OK` with
   0 rows only in the baseline and 0 rows only in the new build. If the vendor
   also delivered new data, expect only those rows to differ.

### Duplicates and replays

The vendor sometimes resends rows. Every staging model keeps one row per
natural key (`deduplicate` macro), so duplicates can't fan out joins, even
in a plain `dbt run`. Layers of checks catch this class of problem:

| Check | Severity | Catches |
|---|---|---|
| `source_duplicates_<table>`, source `unique` on vendor ids | warn | Any duplicated natural key or id in the raw feed (dropped in staging) |
| `source_conflicting_duplicates_<table>` | error | Duplicates whose copies disagree, where no copy is safe to keep |
| Staging and mart `unique` tests | error | Duplicates that survived staging |
| `assert_fact_row_counts_preserved` | error | Join fan-out: each fact must have exactly as many rows as its staged inputs |
| `assert_constructor_points_reconcile` | error | GP + sprint points per constructor per race must equal the vendor's separate `constructor_results` (1991 on) |
| `assert_driver_points_reconcile_with_standings` | error | Cumulative GP + sprint points per driver must equal the official standings after every round (1991 on) |
| `assert_lap_time_text_matches_ms` | warn | Lap `time` text and `milliseconds` disagree |
| `mon_source_duplicates` (live view) | — | Duplicate keys and extra rows per raw table, at any time |

Run the project with `dbt build`, not `dbt run` followed by `dbt test`. With
`dbt build`, a failing test stops the models downstream of it, so dashboards
keep the last good data instead of receiving bad data before the tests run.

### 2026-10-21 incident: Ferrari totals doubled

- Root cause: the vendor resent Ferrari's `constructors` row (constructor 6,
  name `'Ferrari '` with a trailing space). The constructor join in the results
  model matched both rows, so every Ferrari result appeared twice in
  `fct_results`. Wins (249 to 498), points and pit stops doubled. Other teams
  were unaffected.
- In the same delivery, the standings for race 1142 (2024 Las Vegas) were
  replayed: 23 identical rows under new ids (+100000).
- Also found: the lap-time correction reissued for race 1142 updated
  `milliseconds` (+137 ms on 215 laps) but not the `time` text. The project uses
  milliseconds, so this is reported as a warning.
- Fix: staging dedupe plus the checks above. All marts were verified identical
  to the pre-incident baseline.

### October 2026 vendor pipeline migration

- `LAP_TIMES` was renamed to `LAP_TIMING`. The source table keeps the name
  `lap_timing`, and the staging model is still `stg_f1__lap_times`.
- `RESULTS.POSITIONORDER` and `SPRINT_RESULTS.POSITIONORDER` were renamed to
  `POSITION_ORDER`.
- `PIT_STOPS.DURATION` (text) was dropped. It was never used, because
  `MILLISECONDS` carries the same value.
- `RACES.DATE` changed from `YYYY-MM-DD` to `DD/MM/YYYY`. The session date
  columns are still ISO.
- Missing qualifying times are now always empty strings instead of `\N`.
  Staging already treated both as null.

Verification: every table matched a pre-migration baseline row for row. Every
staging view matched the previous staging SQL run over the pre-migration raw
data, read through Snowflake Time Travel.

## Known data quirks

- Nulls are the literal string `\N`, except missing qualifying times, which are
  empty strings.
- The latest season in the data (2024) is incomplete: rounds 23 and 24 (Qatar, Abu
  Dhabi) are on the calendar but have no results. 2024 standings are as of round 22
  and 2024 does not count as a championship.
- Before 1979, shared cars mean a driver can have several results in one race, and
  a few races have two winners. `result_id` is the grain of `fct_results`.
- In the 2005 Australian GP, two classified finishers (P11 and P14) have a null raw
  `position`. `finish_position` is taken from `positiontext`, so they keep their
  places.
- Michael Schumacher was excluded from the 1997 championship (`positiontext` 'D').
  He keeps his row with a null `championship_position`. McLaren 2007 is marked 'E'
  in the constructor standings.
- 19 driver-seasons with a Grand Prix entry (about half of them 1992–93 entries that never qualified) are
  missing from the official standings snapshot, so they have no standings row.
- For 2015 Manor Marussia, qualifying sometimes records the old Marussia
  constructor id (206) while the race results use 209. `fct_qualifying` keeps the
  source value. The head-to-head mart uses the constructor the driver raced for.
- Pit stop duration comes from the integer `milliseconds` column. 517 stops are over 60 s (red flags) and
  are excluded from the pit stop mart.
- One driver's nationality is `'Argentinian '` (trailing space, different demonym).
  It is standardised to `Argentine`.
- Lap times start in 1996, qualifying in 1994 (sparse until 2003), pit stops in 2011.
